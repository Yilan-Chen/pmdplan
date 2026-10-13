.stop <- function(...) stop(..., call. = TRUE)

.need <- function(package) {
  if (requireNamespace(package, quietly = TRUE)) return(invisible(TRUE))
  prompt <- paste0("The '", package, "' package is required for this function but is not available. Install it now?")
  if (interactive() && isTRUE(getOption("pmdplan.ask_install", TRUE))) {
    install <- if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
      rstudioapi::showQuestion("Install the package", prompt, ok = "Install", cancel = "Cancel")
    } else utils::askYesNo(prompt)
    if (isTRUE(install)) {
      utils::install.packages(package)
      if (requireNamespace(package, quietly = TRUE)) return(invisible(TRUE))
    }
  }
  .stop("Please install the '", package, "' package to use this function: install.packages(\"", package, "\").")
}

.scalar_number <- function(x, name, lower = -Inf, upper = Inf, integer = FALSE) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) ||
      x < lower || x > upper || (integer && x != floor(x)))
    .stop(name, " must be a finite ", if (integer) "integer" else "number",
          " in [", lower, ", ", upper, "].")
}

.strings <- function(x, name, empty = FALSE) {
  if (!is.character(x) || (!empty && !length(x)) || anyNA(x) ||
      any(!nzchar(x)) || any(grepl("[[:cntrl:]]", x)))
    .stop(name, " must contain nonempty character strings without control characters.")
}

.columns <- function(data, columns) {
  if (!is.data.frame(data)) .stop("Expected a data.frame.")
  if (anyDuplicated(names(data))) .stop("Column names must be unique.")
  missing <- setdiff(columns, names(data))
  if (length(missing)) .stop("Missing columns: ", paste(missing, collapse = ", "))
}

.validate_panel <- function(data, id, time, items) {
  .strings(c(id, time), "id and time")
  if (length(id) != 1L || length(time) != 1L || id == time)
    .stop("id and time must name two different columns.")
  .strings(items, "items")
  if (anyDuplicated(items) || any(items %in% c(id, time)))
    .stop("items must be unique and must not include id or time.")
  .columns(data, c(id, time, items))
  if (!nrow(data)) .stop("data must have at least one row.")
  if (anyNA(data[[id]]) || anyNA(data[[time]])) .stop("id/time cannot be missing.")
  .strings(as.character(data[[id]]), "Participant identifiers")
  time_values <- data[[time]]
  valid_time <- (is.numeric(time_values) && !is.complex(time_values)) ||
    is.character(time_values) || is.factor(time_values) ||
    inherits(time_values, "Date") || inherits(time_values, "POSIXct")
  if (!valid_time || !is.null(dim(time_values)))
    .stop("time must contain numeric values, character labels, factors, dates, or date-times.")
  if (is.numeric(time_values) && any(!is.finite(time_values)))
    .stop("Numeric measurement times must be finite.")
  if (is.character(time_values)) .strings(time_values, "Measurement times")
  if (anyDuplicated(data[c(id, time)])) .stop("Duplicate id-time combinations.")
  if (any(!vapply(data[items], function(x) is.atomic(x) && is.null(dim(x)), logical(1))))
    .stop("Item columns must be vectors, such as numeric, character, logical, or factor columns.")
  invisible(TRUE)
}

.with_seed <- function(seed, code) {
  .scalar_number(seed, "seed", 0, .Machine$integer.max, TRUE)
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv)
  old_kind <- RNGkind()
  on.exit({
    do.call(RNGkind, as.list(old_kind))
    if (had_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv)
    else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
      rm(".Random.seed", envir = .GlobalEnv)
  }, add = TRUE)
  set.seed(seed)
  force(code)
}

.key <- function(data, columns) {
  .columns(data, columns)
  xs <- lapply(data[columns], as.character)
  for (x in xs) .strings(x, "Key columns")
  do.call(paste, c(xs, sep = "\037"))
}

.unique_key <- function(data, columns) {
  key <- .key(data, columns)
  if (anyDuplicated(key)) .stop("Duplicate key: ", paste(columns, collapse = ", "))
  key
}

.validate_subsets <- function(data, id, time, subsets, items) {
  if (!is.list(subsets) || !length(subsets) || is.null(names(subsets)))
    .stop("subsets must be a named list containing at least one item subset.")
  .strings(names(subsets), "Subset names")
  if (anyDuplicated(names(subsets))) .stop("Subset names must be unique.")
  for (s in subsets) {
    .strings(s, "Items in each subset")
    if (anyDuplicated(s)) .stop("Item names must be unique within each subset.")
  }
  assigned <- unlist(subsets, use.names = FALSE)
  if (!setequal(assigned, items))
    .stop("subsets must cover exactly all declared items. Missing: ",
          paste(setdiff(items, assigned), collapse = ", "), "; unexpected: ",
          paste(setdiff(assigned, items), collapse = ", "), ".")
  .validate_panel(data, id, time, items)
  items
}

.empty_results <- function() data.frame(condition = character(), design = character(),
  replication = integer(), parameter = character(), estimate = double(),
  sd = double(), lower = double(), upper = double(),
  stringsAsFactors = FALSE)

.validate_estimates <- function(x) {
  .columns(x, c("parameter", "estimate"))
  if (!nrow(x)) .stop("Estimator returned no parameters.")
  .strings(x$parameter, "parameter")
  if (anyDuplicated(x$parameter)) .stop("Estimator returned duplicate parameters.")
  if (!is.numeric(x$estimate)) .stop("estimate must be numeric.")
  for (v in c("sd", "lower", "upper")) {
    if (!v %in% names(x)) x[[v]] <- NA_real_
    if (!is.numeric(x[[v]])) .stop(v, " must be numeric.")
  }
  if (any(x$sd < 0, na.rm = TRUE)) .stop("sd cannot be negative.")
  if (any(x$lower > x$upper, na.rm = TRUE)) .stop("lower exceeds upper.")
  x[c("parameter", "estimate", "sd", "lower", "upper")]
}

.resolve_psr_cutoff <- function(cutoff, n_factors) {
  if (!is.null(n_factors))
    .scalar_number(n_factors, "n_factors", 0, .Machine$integer.max, TRUE)
  if (is.null(cutoff)) {
    if (is.null(n_factors))
      .stop("Supply n_factors to choose the default PSR cutoff, or provide cutoff explicitly.")
    cutoff <- if (n_factors == 1L) 1.05 else 1.10
  }
  .scalar_number(cutoff, "cutoff", 1, Inf)
  cutoff
}

.schedule_settings <- function(settings, name, defaults) {
  if (is.null(settings) || !is.list(settings) || is.data.frame(settings))
    .stop("Supply ", name, " as a named list. Allowed entries: ", paste(names(defaults), collapse = ", "), ".")
  if (length(settings)) {
    .strings(names(settings), paste0(name, " entry names"))
    if (is.null(names(settings)) || anyDuplicated(names(settings)))
      .stop(name, " entries must have unique names.")
    unknown <- setdiff(names(settings), names(defaults))
    if (length(unknown)) .stop("Unknown ", name, " entries: ", paste(unknown, collapse = ", "), ".")
    defaults[names(settings)] <- settings
  }
  defaults
}
