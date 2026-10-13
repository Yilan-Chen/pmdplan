.ensure_directory <- function(path) {
  if (!dir.exists(path)) dir.create(path, recursive = TRUE, showWarnings = TRUE)
  if (!dir.exists(path)) .stop("Could not create directory: ", path)
  invisible(path)
}

.check_cores <- function(mc.cores) {
  .scalar_number(mc.cores, "mc.cores", 1, .Machine$integer.max, TRUE)
  invisible(TRUE)
}

.capture_result <- function(code) {
  tryCatch(list(value = force(code), error = NULL),
    error = function(e) list(value = NULL, error = conditionMessage(e)))
}

.replication_worker <- function(x, task_fun) {
  old <- options(pmdplan.ask_install = FALSE)
  on.exit(options(old), add = TRUE)
  .capture_result(task_fun(x))
}

# Socket workers do not inherit the caller's global environment/search path.
# Collect only bindings referenced by task/design functions, including helpers.
.psock_globals <- function(task_fun) {
  bindings <- list()
  visited <- list()
  visit <- function(value) {
    if (is.function(value) && !is.primitive(value)) {
      env <- environment(value)
      if (isNamespace(env) || identical(env, baseenv()) ||
          any(vapply(visited, identical, logical(1), value))) return(invisible(NULL))
      visited[[length(visited) + 1L]] <<- value
      for (name in codetools::findGlobals(value, merge = TRUE)) {
        owner <- env
        while (!identical(owner, emptyenv()) && !exists(name, owner, inherits = FALSE))
          owner <- parent.env(owner)
        if (identical(owner, emptyenv())) next
        dependency <- get(name, owner, inherits = FALSE)
        if (identical(owner, globalenv()) ||
            (startsWith(environmentName(owner), "package:") && !identical(owner, baseenv())))
          bindings[name] <<- list(dependency)
        visit(dependency)
      }
    } else if (is.list(value) && !is.data.frame(value)) {
      for (element in value) visit(element)
    }
    invisible(NULL)
  }
  visit(task_fun)
  bindings
}

.psock_apply <- function(X, FUN, mc.cores) {
  globals <- .psock_globals(FUN)
  cl <- parallel::makeCluster(mc.cores, type = "PSOCK")
  on.exit(try(parallel::stopCluster(cl), silent = TRUE), add = TRUE)
  setup <- function(paths, rng_kind) {
    .libPaths(paths)
    do.call(RNGkind, as.list(rng_kind))
    NULL
  }
  # This initializer must work before workers can load this package's namespace.
  environment(setup) <- baseenv()
  parallel::clusterCall(cl, setup, .libPaths(), RNGkind())
  if (length(globals)) parallel::clusterExport(cl, names(globals),
    envir = list2env(globals, parent = emptyenv()))
  parallel::parLapply(cl, X, .replication_worker, task_fun = FUN)
}

.replication_apply <- function(X, FUN, mc.cores) {
  .check_cores(mc.cores)
  result <- if (.Platform$OS.type == "windows") .psock_apply(X, FUN, mc.cores) else
    parallel::mclapply(X, .replication_worker, task_fun = FUN,
      mc.cores = mc.cores, mc.set.seed = FALSE, mc.preschedule = FALSE)
  lapply(result, function(x) {
    if (is.null(x) || inherits(x, "try-error"))
      list(value = NULL, error = "Replication worker did not return a result.") else x
  })
}

.validate_manifest <- function(x, design = TRUE) {
  columns <- c("condition", if (design) "design", "replication")
  .columns(x, columns)
  if (!nrow(x)) .stop("The replication manifest cannot be empty.")
  for (v in setdiff(columns, "replication")) {
    x[[v]] <- as.character(x[[v]])
    .strings(x[[v]], v)
  }
  if (!is.numeric(x$replication) || anyNA(x$replication) ||
      any(!is.finite(x$replication) | x$replication < 1 | x$replication != floor(x$replication)))
    .stop("replication must contain positive integer-valued numbers.")
  .unique_key(x, columns)
  x
}

# Apply designs to existing data only; never generate data or fit a model.
pmd_batch <- function(data, designs, metadata = NULL, seed = 1,
                      mc.cores = 1, directory = NULL, include_complete = FALSE) {
  .check_cores(mc.cores)
  if (!is.list(data) || is.data.frame(data) || !length(data))
    .stop("data must be a list containing one existing data.frame per replication.")
  if (!is.list(designs) || !length(designs) || is.null(names(designs)) ||
      anyDuplicated(names(designs)) || !all(vapply(designs, is.function, logical(1))))
    .stop("designs must be a uniquely named list of functions(data, seed) that apply PMD.")
  .strings(names(designs), "Design labels")
  if (!is.logical(include_complete) || length(include_complete) != 1L || is.na(include_complete))
    .stop("include_complete must be TRUE or FALSE.")
  if (include_complete && "complete" %in% names(designs))
    .stop("The design label 'complete' is reserved when include_complete = TRUE.")
  if (is.null(metadata)) metadata <- data.frame(condition = "condition1", replication = seq_along(data))
  metadata <- .validate_manifest(metadata, design = FALSE)
  if (nrow(metadata) != length(data)) .stop("The number of metadata rows must equal the number of input datasets.")
  nd <- length(designs)
  seeds <- .with_seed(seed, matrix(sample.int(.Machine$integer.max,
    length(data) * nd, replace = FALSE), nrow = length(data)))
  if (!is.null(directory)) {
    .strings(directory, "directory")
    if (length(directory) != 1L) .stop("directory must be one path or NULL.")
    if (dir.exists(directory) && length(list.files(directory, all.files = TRUE, no.. = TRUE)))
      .stop("directory must be new or empty; existing files are not overwritten.")
    .ensure_directory(directory)
    directory <- normalizePath(directory, winslash = "/", mustWork = TRUE)
  }
  processed <- .replication_apply(seq_along(data), function(i) {
    if (!is.data.frame(data[[i]])) .stop("The supplied replication is not a data.frame.")
    lapply(seq_along(designs), function(j)
      .capture_result(.with_seed(seeds[i, j], {
        result <- designs[[j]](data = data[[i]], seed = seeds[i, j])
        if (!inherits(result, "pmd_data")) .stop("Each design must return a pmd_data object.")
        result
      })))
  }, mc.cores)
  objects <- list(); rows <- list(); burden <- list()
  labels <- c(names(designs), if (include_complete) "complete")
  for (i in seq_along(data)) for (j in seq_along(labels)) {
    baseline <- j > nd
    ans <- if (baseline) .capture_result({
      if (!is.data.frame(data[[i]])) .stop("The supplied replication is not a data.frame.")
      data[[i]]
    }) else if (!is.null(processed[[i]]$error)) processed[[i]] else processed[[i]]$value[[j]]
    key <- if (baseline) paste0("r", i, "_complete") else paste0("r", i, "_d", j)
    path <- NA_character_
    if (is.null(ans$error)) {
      objects[key] <- list(ans$value)
      if (!baseline) burden[[length(burden) + 1L]] <- data.frame(metadata[i, c("condition", "replication"), drop = FALSE],
        design = names(designs)[j], ans$value$metadata[setdiff(names(ans$value$metadata), "design")],
        stringsAsFactors = FALSE)
      if (!is.null(directory)) {
        path <- file.path(directory, paste0(key, ".rds"))
        saveRDS(ans$value, path)
      }
    } else objects[key] <- list(NULL)
    rows[[length(rows) + 1L]] <- data.frame(metadata[i, c("condition", "replication"), drop = FALSE],
      design = labels[j], object = key, seed = if (baseline) NA_integer_ else seeds[i, j],
      status = if (is.null(ans$error)) "ok" else "design_error",
      error = if (is.null(ans$error)) "" else ans$error, file = path, stringsAsFactors = FALSE)
  }
  manifest <- do.call(rbind, rows); rownames(manifest) <- NULL
  out <- list(data = objects, manifest = manifest,
    burden = if (length(burden)) do.call(rbind, burden) else data.frame(),
    metadata = metadata, seeds = seeds, directory = directory)
  if (!is.null(directory)) {
    utils::write.csv(manifest, file.path(directory, "manifest.csv"), row.names = FALSE, na = "")
  }
  out
}
