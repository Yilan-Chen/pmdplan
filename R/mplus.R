obtain_map <- function(file, path = ".") {
  .need("MplusAutomation")
  .strings(file, "file")
  if (length(file) != 1L || !file.exists(file)) .stop("Provide one existing .out file.")
  .strings(path, "path")
  if (length(path) != 1L) .stop("path must be one output directory.")
  destination <- file.path(path, "map.csv")
  if (identical(normalizePath(file), normalizePath(destination, mustWork = FALSE)))
    .stop("map.csv must not overwrite the input file.")
  out <- MplusAutomation::readModels(file, what = "parameters")
  pars <- out$parameters$unstandardized
  if (is.null(pars) || !nrow(pars)) .stop("Mplus parameter table unavailable or empty: unstandardized")
  .columns(pars, c("paramHeader", "param"))
  identifiers <- c("paramHeader", "param")
  if ("BetweenWithin" %in% names(pars)) identifiers <- c(identifiers, "BetweenWithin")
  map <- as.data.frame(pars)[identifiers]
  .unique_key(map, identifiers)
  map <- data.frame(parameter = rep("", nrow(map)), map, stringsAsFactors = FALSE)
  rownames(map) <- NULL
  .ensure_directory(path)
  utils::write.csv(map, file = destination, row.names = FALSE, na = "")
  map
}

read_mplus_estimates <- function(file, map, cutoff = NULL,
                                 n_factors = NULL, max_iterations = 50000) {
  .resolve_psr_cutoff(cutoff, n_factors)
  .scalar_number(max_iterations, "max_iterations", 1, .Machine$integer.max, TRUE)
  .need("MplusAutomation")
  if (length(file) != 1L || !file.exists(file)) .stop("Provide one existing .out file.")
  .columns(map, c("parameter", "paramHeader", "param"))
  match_columns <- setdiff(names(map), "parameter")
  map$parameter <- trimws(as.character(map$parameter))
  selected <- !is.na(map$parameter) & nzchar(map$parameter)
  map <- map[selected, , drop = FALSE]
  if (!nrow(map)) .stop("Fill in parameter names for at least one row in map.csv.")
  .strings(map$parameter, "parameter")
  if (anyDuplicated(map$parameter)) .stop("map parameter names must be unique.")
  .unique_key(map, match_columns)
  out <- MplusAutomation::readModels(file, what = c("parameters", "tech8", "warn_err"))
  diag <- mplus_convergence(out, cutoff = cutoff, n_factors = n_factors,
    max_iterations = max_iterations)
  pars <- out$parameters$unstandardized
  if (is.null(pars)) .stop("Mplus parameter table unavailable: unstandardized")
  .columns(pars, c(match_columns, "est", "posterior_sd", "lower_2.5ci", "upper_2.5ci"))
  indices <- vapply(seq_len(nrow(map)), function(i) {
    keep <- rep(TRUE, nrow(pars))
    for (column in match_columns)
      keep <- keep & !is.na(pars[[column]]) & as.character(pars[[column]]) == as.character(map[[column]][i])
    candidates <- which(keep)
    if (length(candidates) != 1L)
      .stop("Parameter '", map$parameter[i], "' matched ", length(candidates),
            " rows. Add the needed level/group identifiers to map.")
    candidates
  }, integer(1))
  get_column <- function(name) {
    if (!is.numeric(pars[[name]])) .stop("Non-numeric output column: ", name)
    pars[[name]][indices]
  }
  result <- data.frame(parameter = map$parameter, estimate = get_column("est"),
    sd = get_column("posterior_sd"), lower = get_column("lower_2.5ci"), upper = get_column("upper_2.5ci"),
    stringsAsFactors = FALSE)
  result <- .validate_estimates(result)
  result$converged <- diag$converged
  attr(result, "mplus_diagnostics") <- diag
  result
}

# Mplus complete-data generation and shared DSEM template.
# Expand explicitly supplied population values to named template parameters.
.generation_values <- function(x, keys, label, lower = -Inf) {
  if (!is.numeric(x) || !length(x) || any(!is.finite(x)) || any(x < lower))
    .stop(label, " must contain finite numeric values", if (is.finite(lower)) paste0(" >= ", lower), ".")
  if (length(x) == 1L && is.null(names(x))) return(stats::setNames(rep(x, length(keys)), keys))
  if (is.null(names(x)) || anyDuplicated(names(x)) || !setequal(names(x), keys))
    .stop(label, " must be one unnamed shared value or a named vector for: ", paste(keys, collapse = ", "))
  x[keys]
}

.dsem_items <- function(items) {
  if (!is.list(items) || !setequal(names(items), c("Sy", "Sx", "Ty", "Tx")) || anyDuplicated(names(items)))
    .stop("Default items must be a named list with Sy, Sx, Ty and Tx.")
  for (its in items) .strings(its, "Factor items")
  within_items <- c(items$Sy, items$Sx)
  between_items <- c(items$Ty, items$Tx)
  if (anyDuplicated(within_items) || anyDuplicated(between_items) || !setequal(within_items, between_items))
    .stop("Sy/Sx and Ty/Tx must each list every observed item once, using the same item names.")
  within_items
}

.dsem_dynamic <- function(all_items) {
  c("phi1 | Sy ON Sy&1;", "phi2 | Sx ON Sx&1;",
    "phi3 | Sx ON Sy&1;", "phi4 | Sy ON Sx&1;", "NCov BY Sy@1 Sx@1;",
    paste0("err", seq_along(all_items), " | ", all_items, ";"),
    "logVSy | Sy;", "logVSx | Sx;", "logcov | NCov;")
}

.dsem_analysis_model <- function(items) {
  all_items <- .dsem_items(items)
  dynamic <- .dsem_dynamic(all_items)
  phi <- paste0("phi", 1:4)
  errors <- paste0("err", seq_along(all_items))
  c("MODEL:", "%WITHIN%", paste0("Sy BY ", items$Sy, "*(&1);"),
    paste0("Sx BY ", items$Sx, "*(&1);"), dynamic, "%BETWEEN%",
    paste0("[", phi, "] ;"), paste0("[", errors, "] ;"), "[logVSy@0];", "[logVSx@0];", "[logcov];",
    paste0(phi, ";"), paste0(errors, ";"), "logVSy;", "logVSx;", "logcov;",
    paste0("Ty BY ", items$Ty, "*;"), paste0("Tx BY ", items$Tx, "*;"),
    paste0("[", all_items, "];"), paste0(all_items, ";"),
    "[Ty@0];", "[Tx@0];", "Ty@1;", "Tx@1;", "Ty WITH Tx;")
}

.dsem_generation_model <- function(items, population_values) {
  within_items <- .dsem_items(items)
  required <- c("within_loadings", "between_loadings", "phi_mean", "phi_variance",
    "mean_logerror", "var_logerror", "var_logre", "mean_logcov", "var_logcov",
    "intercepts", "between_residual_variances", "latent_covariance")
  if (!is.list(population_values) || is.data.frame(population_values) || is.null(names(population_values)) ||
      anyDuplicated(names(population_values)) || !setequal(names(population_values), required))
    .stop("Default population_values must be a named list containing exactly: ", paste(required, collapse = ", "))
  all_items <- within_items
  keys <- list(within_loadings = all_items, between_loadings = all_items,
    phi_mean = paste0("phi", 1:4), phi_variance = paste0("phi", 1:4),
    mean_logerror = all_items, var_logerror = all_items,
    var_logre = c("Sy", "Sx"),
    mean_logcov = "NCov", var_logcov = "NCov", intercepts = all_items,
    between_residual_variances = all_items, latent_covariance = "Ty_WITH_Tx")
  nonnegative <- c("phi_variance", "var_logerror", "var_logre", "var_logcov",
    "between_residual_variances")
  v <- lapply(required, function(nm) .generation_values(population_values[[nm]], keys[[nm]], nm,
    if (nm %in% nonnegative) 0 else -Inf))
  names(v) <- required
  if (abs(v$latent_covariance) >= 1)
    .stop("latent_covariance must be strictly between -1 and 1 because Ty and Tx variances are fixed at 1.")
  fmt <- function(x) format(x, digits = 15, scientific = FALSE, trim = TRUE, decimal.mark = ".")
  fixed <- function(names, values, mean = FALSE) {
    text <- paste0(names, "@", fmt(values))
    paste0(if (mean) "[" else "", text, if (mean) "];" else ";")
  }
  dynamic <- .dsem_dynamic(all_items)
  phi <- paste0("phi", 1:4); errors <- paste0("err", seq_along(all_items)); logv <- c("logVSy", "logVSx")
  c("ANALYSIS:", "TYPE = TWOLEVEL RANDOM;", "ESTIMATOR = BAYES;",
    "PROCESSORS = 2;", "FBITERATIONS = 100;",
    "MODEL POPULATION:", "%WITHIN%",
    paste0("Sy BY ", items$Sy, "@", fmt(v$within_loadings[items$Sy]), "(&1);"),
    paste0("Sx BY ", items$Sx, "@", fmt(v$within_loadings[items$Sx]), "(&1);"), dynamic,
    "%BETWEEN%", fixed(phi, v$phi_mean, TRUE), fixed(errors, v$mean_logerror, TRUE),
    "[logVSy@0];", "[logVSx@0];", fixed("logcov", v$mean_logcov, TRUE),
    fixed(phi, v$phi_variance), fixed(errors, v$var_logerror),
    fixed(logv, v$var_logre), fixed("logcov", v$var_logcov),
    paste0("Ty BY ", items$Ty, "@", fmt(v$between_loadings[items$Ty]), ";"),
    paste0("Tx BY ", items$Tx, "@", fmt(v$between_loadings[items$Tx]), ";"),
    fixed(all_items, v$intercepts, TRUE), fixed(all_items, v$between_residual_variances),
    "[Ty@0];", "[Tx@0];", "Ty@1;", "Tx@1;",
    paste0("Ty WITH Tx@", fmt(v$latent_covariance), ";"),
    .dsem_analysis_model(items), "OUTPUT: TECH8;")
}

.mplus_generation_columns <- function(output_file) {
  lines <- readLines(output_file, warn = FALSE)
  start <- grep("^\\s*SAVEDATA INFORMATION\\s*$", lines)
  if (!length(start)) .stop("No SAVEDATA INFORMATION found. Inspect ", output_file)
  lines <- lines[seq.int(utils::tail(start, 1L), length(lines))]
  order <- grep("^\\s*Order of variables\\s*$", lines, ignore.case = TRUE)
  if (!length(order)) .stop("Saved variable order unavailable. Inspect ", output_file)
  tail_lines <- trimws(lines[seq.int(order[1L] + 1L, length(lines))])
  nonempty <- which(nzchar(tail_lines))
  if (!length(nonempty)) .stop("Saved variable order is empty.")
  tail_lines <- tail_lines[seq.int(nonempty[1L], length(tail_lines))]
  end <- which(!nzchar(tail_lines))
  columns <- if (length(end)) utils::head(tail_lines, end[1L] - 1L) else tail_lines
  if (!length(columns) || any(!grepl("^[A-Za-z][A-Za-z0-9_]*$", columns)) || anyDuplicated(toupper(columns)))
    .stop("Cannot identify saved data columns. Inspect ", output_file)
  toupper(columns)
}

# Mplus creates all replications in a single Monte Carlo run.
generate_mplus_data <- function(
    items = list(Sy = c("y1", "y2", "y3"), Sx = c("x1", "x2", "x3"),
                 Ty = c("y1", "y2", "y3"), Tx = c("x1", "x2", "x3")),
    N, TT, replication, modelstring = NULL,
    population_values = list(
      within_loadings = c(y1=.8, y2=.6, y3=.6, x1=.8, x2=.6, x3=.6),
      between_loadings = .7,
      phi_mean = c(phi1=.2, phi2=.2, phi3=.1, phi4=.1),
      phi_variance = .01, mean_logerror = log(.3), var_logerror = .05,
      var_logre = .05, mean_logcov = log(.05), var_logcov = .01,
      intercepts = 0, between_residual_variances = .2, latent_covariance = .2),
    path = "mplus_generation", seed = 1, run = TRUE, Mplus_command = NULL) {
  for (nm in c("N", "TT", "replication"))
    .scalar_number(get(nm), nm, 1, .Machine$integer.max, TRUE)
  .scalar_number(seed, "seed", 1, .Machine$integer.max, TRUE)
  if (N * TT > .Machine$integer.max) .stop("N * TT is too large.")
  if (!is.logical(run) || length(run) != 1L || is.na(run)) .stop("run must be TRUE or FALSE.")
  all_items <- if (is.list(items)) unique(unlist(items, use.names = FALSE)) else items
  .strings(all_items, "items")
  if (anyDuplicated(toupper(all_items)) || any(!grepl("^[A-Za-z][A-Za-z0-9_]{0,7}$", all_items)) ||
      any(toupper(all_items) %in% c("ID", "TIME", "CLUSTER")))
    .stop("Use unique Mplus item names of 1-8 letters/digits/underscores, starting with a letter; id/time/cluster are reserved.")
  if (is.null(modelstring)) {
    reserved <- c("SY", "SX", "TY", "TX", "NCOV", "LOGVSY", "LOGVSX", "LOGCOV", paste0("PHI", 1:4), paste0("ERR", seq_along(all_items)))
    conflicts <- all_items[toupper(all_items) %in% reserved]
    if (length(conflicts)) .stop("Rename these observed variables because their names are used by the default DSEM template: ", paste(conflicts, collapse = ", "), ".")
    body <- .dsem_generation_model(items, population_values)
  } else {
    if (missing(population_values)) population_values <- NULL
    if (!is.null(population_values)) .stop("When using a custom modelstring, omit population_values because the population values are already specified in its MODEL POPULATION: section.")
    if (!is.character(modelstring) || !length(modelstring) || anyNA(modelstring)) .stop("modelstring must be Mplus syntax text.")
    body <- unlist(strsplit(modelstring, "\n", fixed = TRUE), use.names = FALSE)
    uncommented <- paste(sub("!.*$", "", body), collapse = "\n")
    if (!grepl("MODEL\\s+POPULATION\\s*:", uncommented, ignore.case = TRUE) ||
        !grepl("ANALYSIS\\s*:", uncommented, ignore.case = TRUE) || !grepl("MODEL\\s*:", uncommented, ignore.case = TRUE))
      .stop("modelstring must include ANALYSIS:, MODEL POPULATION: and MODEL: sections.")
    if (grepl("(^|[;\\n])\\s*(MONTECARLO|DATA|VARIABLE|SAVEDATA|TITLE)\\s*:", uncommented, ignore.case = TRUE))
      .stop("modelstring must include ANALYSIS:, MODEL POPULATION: and MODEL:, and may include OUTPUT:. Do not include TITLE:, MONTECARLO:, DATA:, VARIABLE: or SAVEDATA:; the function controls data-generation and save settings.")
    if (any(nchar(body, type = "chars") > 90L)) .stop("Keep each modelstring line at most 90 characters for Mplus.")
  }
  .strings(path, "path")
  if (length(path) != 1L) .stop("path must be one directory.")
  if (dir.exists(path) && length(list.files(path, all.files = TRUE, no.. = TRUE)))
    .stop("path must be new or empty so generated files cannot overwrite earlier results.")
  if (run) .need("MplusAutomation")
  .ensure_directory(path)
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  input <- file.path(path, "generation.inp"); output <- file.path(path, "generation.out")
  syntax <- c("TITLE: Complete data generation;", "MONTECARLO:", paste0("NAMES ARE ", paste(all_items, collapse = " "), ";"),
    paste0("NOBSERVATIONS = ", N * TT, ";"), "NCSIZES = 1;", paste0("CSIZES = ", N, "(", TT, ");"),
    paste0("NREP = ", replication, ";"), paste0("SEED = ", seed, ";"), "REPSAVE = ALL;", "SAVE = rep*.dat;", body)
  writeLines(syntax, input, useBytes = TRUE)
  manifest <- data.frame(replication = seq_len(replication), status = "not_run",
    dat = file.path(path, paste0("rep", seq_len(replication), ".dat")), rds = NA_character_, error = "")
  data <- stats::setNames(rep(list(NULL), replication), paste0("rep", seq_len(replication)))
  if (run) {
    old_wd <- getwd()
    on.exit(setwd(old_wd), add = TRUE)
    setwd(path)
    args <- list(target = input)
    if (!is.null(Mplus_command)) { .strings(Mplus_command, "Mplus_command"); if (length(Mplus_command) != 1L) .stop("Mplus_command must be one executable path."); args$Mplus_command <- Mplus_command }
    do.call(MplusAutomation::runModels, args)
    if (!file.exists(output)) .stop("Mplus did not create generation.out. Inspect ", path)
    columns <- .mplus_generation_columns(output)
    for (i in seq_len(replication)) {
      ans <- .capture_result({
        if (!file.exists(manifest$dat[i])) .stop("Replication data file was not generated.")
        raw <- utils::read.table(manifest$dat[i], header = FALSE, colClasses = "numeric")
        if (ncol(raw) != length(columns)) .stop("The number of data columns differs from SAVEDATA INFORMATION.")
        names(raw) <- columns
        if (!all(c(toupper(all_items), "CLUSTER") %in% columns)) .stop("Expected item/CLUSTER columns not found.")
        id <- raw$CLUSTER
        if (any(!is.finite(id)) || length(unique(id)) != N || any(table(id) != TT)) .stop("Generated participant counts do not match N and TT.")
        time <- if ("TIME" %in% columns) raw$TIME else stats::ave(seq_along(id), id, FUN = seq_along)
        d <- data.frame(id = id, time = time, raw[toupper(all_items)], check.names = FALSE)
        names(d) <- c("id", "time", all_items)
        .validate_panel(d, "id", "time", all_items)
        if (nrow(d) != N * TT || any(!is.finite(as.matrix(d[all_items])))) .stop("Generated data are not complete and finite.")
        rds <- file.path(path, paste0("rep", i, ".rds")); saveRDS(d, rds)
        list(data = d, rds = rds)
      })
      if (is.null(ans$error)) {
        data[i] <- list(ans$value$data); manifest$status[i] <- "generated"; manifest$rds[i] <- ans$value$rds
      } else { manifest$status[i] <- "generation_error"; manifest$error[i] <- ans$error }
    }
    if (any(manifest$status == "generation_error")) warning("Some replications could not be imported; inspect manifest and generation.out.", call. = FALSE)
  }
  utils::write.csv(manifest, file.path(path, "manifest.csv"), row.names = FALSE, na = "")
  list(data = data, manifest = manifest, items = all_items, input = input, output = output,
    modelstring = paste(syntax, collapse = "\n"), population_values = population_values,
    N = N, TT = TT, replication = replication, path = path)
}

# Batch Mplus analysis.
# BITERATIONS is either a maximum, a parenthesized minimum, or both.
.mplus_biterations <- function(x) {
  if (is.numeric(x) && length(x) == 1L && is.finite(x))
    x <- format(x, scientific = FALSE, trim = TRUE)
  if (!is.character(x) || length(x) != 1L || is.na(x))
    .stop("biterations must be text such as '(1000)' or '50000 (2000)'.")
  x <- trimws(x)
  if (!grepl("^([1-9][0-9]*(\\s*\\([0-9]+\\))?|\\([0-9]+\\))$", x))
    .stop("biterations must be a maximum, '(minimum)', or 'maximum (minimum)'.")
  values <- as.numeric(regmatches(x, gregexpr("[0-9]+", x))[[1L]])
  maximum <- if (startsWith(x, "(")) 50000 else values[1L]
  minimum <- if (startsWith(x, "(")) values[1L] else if (length(values) == 2L) values[2L] else 0
  .scalar_number(maximum, "Maximum BITERATIONS", 1, .Machine$integer.max, TRUE)
  .scalar_number(minimum, "Minimum BITERATIONS", 0, maximum, TRUE)
  list(text = x, max_iterations = maximum, min_iterations = minimum)
}

# One missing flag is used consistently in exported data and Mplus syntax.
.mplus_missing_flag <- function(x) {
  if (length(x) != 1L || is.na(x) || !(is.numeric(x) || is.character(x)))
    .stop("missing must be one finite numeric flag, '.', '*', or 'BLANK'.")
  text <- trimws(as.character(x))
  blank <- !nzchar(text) || toupper(text) == "BLANK"
  if (blank) return(list(text = "", syntax = "MISSING = BLANK;", numeric = NULL, blank = TRUE))
  if (text %in% c(".", "*"))
    return(list(text = text, syntax = paste0("MISSING = ", text, ";"), numeric = NULL, blank = FALSE))
  value <- suppressWarnings(as.numeric(text))
  if (is.na(value) || !is.finite(value))
    .stop("missing must be one finite numeric flag, '.', '*', or 'BLANK'.")
  text <- format(value, digits = 15, scientific = FALSE, trim = TRUE, decimal.mark = ".")
  list(text = text, syntax = paste0("MISSING = ALL (", text, ");"), numeric = value, blank = FALSE)
}

.check_mplus_names <- function(x) {
  .strings(x, "Variable names")
  invalid <- x[!grepl("^[A-Za-z][A-Za-z0-9_]{0,7}$", x)]
  if (length(invalid)) .stop("Rename these variables to meet Mplus's 1-8 character naming rule (letter first, then letters/digits/underscores): ", paste(invalid, collapse = ", "), ".")
  duplicates <- x[duplicated(toupper(x)) | duplicated(toupper(x), fromLast = TRUE)]
  if (length(duplicates)) .stop("Variable names must be unique ignoring case. Rename: ", paste(duplicates, collapse = ", "), ".")
}

.mplus_file_reference <- function(path) {
  chars <- strsplit(path, "", fixed = TRUE)[[1L]]
  lines <- character(); part <- ""
  for (ch in chars) {
    if (nchar(paste0(part, ch), type = "bytes") > 70L) {
      lines <- c(lines, part); part <- ""
    }
    part <- paste0(part, ch)
  }
  paste(c(lines, part), collapse = "\n")
}

# Preserve Unicode labels; the task index prevents sanitized-name collisions.
.mplus_path_label <- function(x) {
  x <- gsub("[/\\\\:*?\"<>|[:cntrl:]]+", "_", x)
  x <- substr(x, 1L, 50L)
  ifelse(nzchar(x), x, "label")
}

# Prepare each dataset in its own directory; evaluate_pmd reads model results.
analyze_mplus <- function(data,
    items = list(Sy = c("y1", "y2", "y3"), Sx = c("x1", "x2", "x3"),
                 Ty = c("y1", "y2", "y3"), Tx = c("x1", "x2", "x3")),
    id = "id", time = "time", modelstring = NULL, metadata = NULL,
    data_names = NULL, processors = 2, biterations = "(1000)", mc.cores = 1,
    path = "mplus_analysis", time_interval = 1, missing = -9999,
    run = TRUE, Mplus_command = NULL) {
  .check_cores(mc.cores)
  custom_mode <- !is.null(modelstring)
  all_items <- NULL
  model <- NULL
  if (!is.logical(run) || length(run) != 1L || is.na(run)) .stop("run must be TRUE or FALSE.")
  if (!custom_mode) {
    .scalar_number(processors, "processors", 1, .Machine$integer.max, TRUE)
    iterations <- .mplus_biterations(biterations)
    if (!is.null(time_interval)) {
      .scalar_number(time_interval, "time_interval", 0, Inf)
      if (time_interval == 0) .stop("time_interval must be positive.")
    }
    missing_flag <- .mplus_missing_flag(missing)
    if (missing_flag$blank)
      .stop("Blank missing flags require an existing fixed-format DAT file and a complete modelstring with FORMAT and MISSING declarations.")
    .strings(c(id, time), "id and time")
    if (length(id) != 1L || length(time) != 1L || id == time)
      .stop("id and time must name two different columns.")
    all_items <- if (is.list(items)) unique(unlist(items, use.names = FALSE)) else items
    .check_mplus_names(all_items)
    if (any(all_items %in% c(id, time))) .stop("items must not include the id or time column.")
    reserved <- c("SY", "SX", "TY", "TX", "NCOV", "LOGVSY", "LOGVSX", "LOGCOV",
      paste0("PHI", 1:4), paste0("ERR", seq_along(all_items)))
    conflicts <- all_items[toupper(all_items) %in% reserved]
    if (length(conflicts)) .stop("Rename these observed variables because their names are used by the default DSEM template: ", paste(conflicts, collapse = ", "), ".")
    model <- .dsem_analysis_model(items)
    if (!is.null(data_names)) .check_mplus_names(data_names)
  }
  upstream_error <- NULL
  if (is.list(data) && !is.data.frame(data) && !inherits(data, "pmd_data") &&
      all(c("data", "manifest") %in% names(data))) {
    original <- data
    .columns(original$manifest, "replication")
    if ("object" %in% names(original$manifest)) {
      if (any(!original$manifest$object %in% names(original$data)))
        .stop("Some pmd_batch manifest objects are absent from data.")
      data <- original$data[original$manifest$object]
    } else data <- original$data
    if (is.null(metadata)) {
      metadata <- original$manifest[intersect(c("condition", "design", "replication"), names(original$manifest))]
      if (!"design" %in% names(metadata)) metadata$design <- "complete"
    }
    if ("error" %in% names(original$manifest)) upstream_error <- original$manifest$error
  }
  if (is.data.frame(data) || inherits(data, "pmd_data")) data <- list(data)
  if (is.character(data)) data <- as.list(data)
  if (!is.list(data) || !length(data))
    .stop("data must contain data.frames, pmd_data objects, RDS/DAT paths, or a generation/pmd_batch result.")
  if (custom_mode) {
    if (is.character(modelstring)) {
      scripts <- rep(list(modelstring), length(data))
    } else if (is.list(modelstring) && !is.data.frame(modelstring) && length(modelstring) == length(data)) {
      scripts <- modelstring
    } else .stop("modelstring must be one complete character script, or a list with one complete script per dataset, including complete-data and failed entries.")
    valid <- vapply(scripts, function(x)
      is.character(x) && length(x) > 0L && !anyNA(x) && any(nzchar(trimws(x))), logical(1))
    if (any(!valid)) .stop("Each modelstring entry must contain nonempty complete Mplus syntax. Invalid entries: ", paste(which(!valid), collapse = ", "), ".")
  }
  if (is.null(metadata)) metadata <- data.frame(design = "analysis", replication = seq_along(data))
  .columns(metadata, c("design", "replication"))
  if (!"condition" %in% names(metadata)) metadata$condition <- "condition1"
  metadata <- .validate_manifest(metadata)[c("condition", "design", "replication")]
  if (nrow(metadata) != length(data)) .stop("The number of metadata rows must equal the number of input datasets.")
  if (is.null(upstream_error)) upstream_error <- rep("", length(data))
  if (length(upstream_error) != length(data)) .stop("The input manifest and data lengths differ.")
  .strings(path, "path")
  if (length(path) != 1L) .stop("path must be one directory.")
  if (dir.exists(path) && length(list.files(path, all.files = TRUE, no.. = TRUE)))
    .stop("path must be new or empty; earlier analysis files are not overwritten.")
  if (!is.null(Mplus_command)) {
    .strings(Mplus_command, "Mplus_command")
    if (length(Mplus_command) != 1L) .stop("Mplus_command must be one executable path.")
  }
  if (run) .need("MplusAutomation")
  .ensure_directory(path)
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  directories <- file.path(path, paste0("fit", seq_along(data), "_",
    .mplus_path_label(metadata$condition), "_", .mplus_path_label(metadata$design),
    "_rep", metadata$replication))
  filenames <- paste0("data_rep", metadata$replication, "_",
    .mplus_path_label(metadata$design), ".dat")
  data_paths <- file.path(directories, filenames)
  for (i in seq_along(data)) {
    d <- data[[i]]
    if (is.character(d) && length(d) == 1L && !is.na(d) && tolower(tools::file_ext(d)) != "rds")
      data_paths[i] <- if (custom_mode) d else normalizePath(d, winslash = "/", mustWork = FALSE)
  }
  manifest <- data.frame(metadata, status = "not_run", error = "",
    dat = data_paths, input = file.path(directories, "analysis.inp"),
    output = file.path(directories, "analysis.out"), stringsAsFactors = FALSE)
  fmt <- function(x) format(x, digits = 15, scientific = FALSE, trim = TRUE, decimal.mark = ".")
  processed <- .replication_apply(seq_along(data), function(i) {
    d <- data[[i]]
    if (is.null(d)) .stop("Input dataset unavailable. ", upstream_error[i])
    dat_source <- NULL
    if (is.character(d)) {
      .strings(d, "Dataset file")
      if (length(d) != 1L) .stop("Each data entry must be one file path.")
      if (tolower(tools::file_ext(d)) == "rds") d <- readRDS(d) else {
        dat_source <- d
        if (!custom_mode) {
          if (!file.exists(d)) .stop("Dataset file does not exist.")
          if (is.null(data_names)) .stop("For DAT input, supply data_names for every saved column in order.")
          dat_source <- normalizePath(d, winslash = "/", mustWork = TRUE)
        }
      }
    }
    if (is.null(dat_source)) {
      if (custom_mode) missing_flag <- .mplus_missing_flag(missing)
      if (missing_flag$blank) .stop("Blank missing flags require an existing fixed-format DAT file; R data use free-format export.")
      if (inherits(d, "pmd_data")) d <- d$data
      if (!is.data.frame(d) || !nrow(d)) .stop("The input must be a nonempty data.frame.")
      if (!custom_mode) .validate_panel(d, id, time, all_items)
      if (!custom_mode && (!is.numeric(d[[id]]) || any(!is.finite(d[[id]])) || any(d[[id]] != floor(d[[id]]))))
        .stop("Mplus input requires finite integer-valued numeric participant IDs.")
      variable_names <- names(d)
      if (!custom_mode) .check_mplus_names(variable_names)
      nonnumeric <- variable_names[!vapply(d, is.numeric, logical(1))]
      if (length(nonnumeric)) .stop("Recode these columns as numeric values before Mplus export: ", paste(nonnumeric, collapse = ", "), ".")
      if (any(vapply(d, function(x) any(is.infinite(x)), logical(1)))) .stop("Data columns cannot contain infinite values.")
      if (!custom_mode) d <- d[order(d[[id]], d[[time]]), , drop = FALSE]
      if (!is.null(missing_flag$numeric) && any(as.matrix(d) == missing_flag$numeric, na.rm = TRUE))
        .stop("The missing code occurs in observed data; choose a different missing value.")
    } else if (!custom_mode) {
      variable_names <- data_names
      required <- c(id, all_items, if (!is.null(time_interval)) time)
      missing_names <- setdiff(required, variable_names)
      if (length(missing_names))
        .stop("Required names are missing from data_names: ", paste(missing_names, collapse = ", "), ".")
    }
    if (!custom_mode) {
      conflicts <- variable_names[toupper(variable_names) %in% reserved]
      if (length(conflicts)) .stop("Rename these observed variables because their names are used by the default DSEM template: ", paste(conflicts, collapse = ", "), ".")
    }
    .ensure_directory(directories[i])
    if (is.null(dat_source)) {
      utils::write.table(d, file = manifest$dat[i], row.names = FALSE,
        col.names = FALSE, na = missing_flag$text)
    }
    if (custom_mode) {
      syntax <- scripts[[i]]
    } else {
      syntax <- c("TITLE: PMD data analysis;", "DATA:",
        paste0('FILE = "', if (is.null(dat_source)) filenames[i] else .mplus_file_reference(dat_source), '";'),
        "VARIABLE:", "NAMES ARE", paste0("  ", variable_names), ";",
        "USEVARIABLES ARE", paste0("  ", all_items), ";", paste0("CLUSTER = ", id, ";"),
        if (!is.null(time_interval)) paste0("TINTERVAL = ", time, " (", fmt(time_interval), ");"),
        missing_flag$syntax, "ANALYSIS:", "TYPE = TWOLEVEL RANDOM;", "ESTIMATOR = BAYES;",
        paste0("PROCESSORS = ", processors, ";"), paste0("BITERATIONS = ", iterations$text, ";"),
        model, "OUTPUT: TECH8;")
    }
    writeLines(syntax, manifest$input[i], useBytes = TRUE)
    if (run) {
      old_wd <- getwd()
      on.exit(setwd(old_wd), add = TRUE)
      setwd(directories[i])
      args <- list(target = manifest$input[i])
      if (!is.null(Mplus_command)) args$Mplus_command <- Mplus_command
      do.call(MplusAutomation::runModels, args)
      if (!file.exists(manifest$output[i])) .stop("Mplus did not create analysis.out.")
    }
    if (run) "output_created" else "prepared"
  }, mc.cores)
  for (i in seq_along(processed)) {
    ans <- processed[[i]]
    if (is.null(ans$error)) manifest$status[i] <- ans$value else {
      manifest$status[i] <- "analysis_error"
      manifest$error[i] <- ans$error
    }
  }
  utils::write.csv(manifest, file.path(path, "manifest.csv"), row.names = FALSE, na = "")
  if (any(manifest$status == "analysis_error"))
    warning("Some datasets could not be prepared or analyzed; inspect manifest. Retain these rows when evaluating convergence.", call. = FALSE)
  list(manifest = manifest, output = manifest$output, metadata = metadata,
    items = all_items, modelstring = if (custom_mode) modelstring else paste(model, collapse = "\n"))
}
