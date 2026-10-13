library(pmdplan)
local({
  err <- function(code, pattern = NULL) {
    x <- tryCatch(force(code), error = identity)
    stopifnot(inherits(x, "error"))
    if (!is.null(pattern)) stopifnot(grepl(pattern, conditionMessage(x), fixed = TRUE))
  }
  e <- data.frame(design = "anchor", replication = 1:20, parameter = "beta",
    estimate = 1, sd = .1, lower = c(rep(.8, 19), 1.1), upper = 1.2, max_psr = 1.01)
  pv <- data.frame(parameter = "beta", value = 1)
  p <- evaluate_pmd(e, pv, cutoff = 1.05)
  stopifnot(p$coverage == .95, p$power == 1, is.na(p$typeI_error), p$eligible,
    !any(c("reference_type", "benchmark_inclusion") %in% names(p)),
    !any(c("reference_type", "mplus_args") %in% names(formals(evaluate_pmd))))
  err(evaluate_pmd(e, pv, cutoff = 1.05, reference_type = "population"), "unused argument")
  err(evaluate_pmd(e, pv, cutoff = 1.05, mplus_args = list()), "unused argument")

  stopifnot(identical(names(formals(read_mplus_estimates)),
    c("file", "map", "cutoff", "n_factors", "max_iterations")))
  for (argument in c("table", "estimate_column", "sd_column", "lower_column",
                     "upper_column", "match_columns")) {
    args <- list(file = "unused.out", map = data.frame(), cutoff = 1.05)
    args[argument] <- list("unused")
    err(do.call(read_mplus_estimates, args), "unused argument")
  }

  if (requireNamespace("MplusAutomation", quietly = TRUE)) {
    file <- system.file("extdata", "ex9.31.out", package = "MplusAutomation")
    if (nzchar(file)) {
      map <- data.frame(parameter = "beta", paramHeader = "SY.ON",
        param = "W", BetweenWithin = "Between")
      # Automatic matching includes all supplied identifiers, including the level.
      automatic <- read_mplus_estimates(file, map, n_factors = 1)
      stopifnot(nrow(automatic) == 1L, automatic$parameter == "beta",
        automatic$estimate == .12, automatic$sd == .016,
        automatic$lower == .09, automatic$upper == .151)
      metadata <- data.frame(design = "anchor", replication = 1)
      result <- evaluate_pmd(file, data.frame(parameter = "beta", value = .12),
        source = "mplus", map = map, metadata = metadata, n_factors = 1)
      stopifnot(result$convergence_rate == 1,
        attr(result, "estimates")$estimate == automatic$estimate)
      # Changing the level must fail; the reader must not silently ignore it.
      wrong <- map; wrong$BetweenWithin <- "Within"
      err(read_mplus_estimates(file, wrong, n_factors = 1), "matched 0 rows")
      failed <- suppressWarnings(evaluate_pmd(file, pv, source = "mplus",
        map = wrong, metadata = metadata, n_factors = 1))
      stopifnot(failed$convergence_rate == 0, failed$n_attempted == 1,
        attr(failed, "replications")$status == "import_error")
      # Every supplied identifier participates; notes are not silently discarded.
      extra <- map; extra$notes <- "this is not an output identifier"
      err(read_mplus_estimates(file, extra, n_factors = 1))
      reordered <- map[c("BetweenWithin", "parameter", "param", "paramHeader")]
      stopifnot(identical(automatic, read_mplus_estimates(file, reordered, n_factors = 1)))
      err(read_mplus_estimates(file, map["parameter"], n_factors = 1))
      # A two-parameter subset follows map order, independent of output order.
      subset_map <- rbind(transform(map, parameter = "beta_xm", param = "XM"), map)
      subset_result <- read_mplus_estimates(file, subset_map, n_factors = 1)
      stopifnot(identical(subset_result$parameter, c("beta_xm", "beta")),
        identical(subset_result$estimate, c(.054, .12)),
        identical(subset_result$sd, c(.014, .016)),
        identical(subset_result$lower, c(.027, .09)),
        identical(subset_result$upper, c(.082, .151)),
        identical(attr(subset_result, "mplus_diagnostics"),
                  attr(automatic, "mplus_diagnostics")))

      original <- MplusAutomation::readModels(file,
        what = c("parameters", "tech8", "warn_err"), quiet = TRUE)
      stopifnot(nrow(original$parameters$unstandardized) > nrow(subset_map))
      # Isolate a reader copy and replace only its parser lookup. Installed
      # namespaces are never modified; controlled parsed outputs exercise schema errors.
      parsed <- original
      reader <- read_mplus_estimates
      parser_env <- new.env(parent = environment(reader))
      parser_env$`::` <- function(pkg, name) {
        stopifnot(identical(substitute(pkg), quote(MplusAutomation)),
                  identical(substitute(name), quote(readModels)))
        function(...) parsed
      }
      environment(reader) <- parser_env
      stopifnot(identical(reader(file, map, n_factors = 1), automatic))
      # A competing se column must never replace posterior_sd.
      parsed$parameters$unstandardized$se <- 999
      stopifnot(identical(reader(file, map, n_factors = 1), automatic))
      for (column in c("est", "posterior_sd", "lower_2.5ci", "upper_2.5ci")) {
        parsed <- original
        parsed$parameters$unstandardized$se <- 999
        parsed$parameters$unstandardized[[column]] <- NULL
        err(reader(file, map, n_factors = 1), paste0("Missing columns: ", column))
        parsed <- original
        parsed$parameters$unstandardized[[column]] <- "not numeric"
        err(reader(file, map, n_factors = 1), paste0("Non-numeric output column: ", column))
      }
      parsed <- original
      parsed$parameters$unstandardized <- NULL
      err(reader(file, map, n_factors = 1), "Mplus parameter table unavailable: unstandardized")
      # Distinguish identical row labels across levels automatically.
      parsed <- original
      extra_row <- parsed$parameters$unstandardized[1, ]
      extra_row$BetweenWithin <- "Within"
      extra_row$est <- 999
      parsed$parameters$unstandardized <- rbind(parsed$parameters$unstandardized, extra_row)
      stopifnot(identical(reader(file, map, n_factors = 1), automatic))
      err(reader(file, map[c("parameter", "paramHeader", "param")], n_factors = 1),
        "matched 2 rows")
      # A selected parameter subset does not override the full-fit TECH8 decision.
      parsed <- original
      parsed$tech8$psr$psr[nrow(parsed$tech8$psr)] <- 1.2
      stopifnot(!reader(file, map, n_factors = 1)$converged)
    }
  }
  cat("Population-value evaluation, argument validation and Mplus level matching passed.\n")
})
