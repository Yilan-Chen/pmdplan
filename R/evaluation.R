.evaluate_estimates <- function(estimates, population_value, replications,
                          exclude_rbias = NULL) {
  if (!is.null(exclude_rbias)) {
    .strings(exclude_rbias, "exclude_rbias")
    if (anyDuplicated(exclude_rbias) || any(!exclude_rbias %in% population_value$parameter))
      .stop("exclude_rbias must contain unique parameter names from population_value.")
  }
  .columns(estimates, c("condition", "design", "replication", "parameter", "estimate"))
  .columns(population_value, c("condition", "parameter", "value"))
  .columns(replications, c("condition", "design", "replication", "status", "converged"))
  if (!nrow(population_value) || !nrow(replications)) .stop("population_value and replications cannot be empty.")
  if (!is.numeric(population_value$value) || any(!is.finite(population_value$value))) .stop("value must be finite numeric values.")
  if (!is.numeric(estimates$estimate) || !is.logical(replications$converged))
    .stop("estimate must be numeric and replications$converged must be logical (TRUE/FALSE/NA).")
  for (v in c("sd", "lower", "upper")) {
    if (!v %in% names(estimates)) estimates[[v]] <- NA_real_
    if (!is.numeric(estimates[[v]])) .stop(v, " must be numeric.")
  }
  if (any(estimates$sd < 0, na.rm = TRUE) || any(estimates$lower > estimates$upper, na.rm = TRUE))
    .stop("Invalid standard deviations or reversed interval bounds.")
  for (dname in c("estimates", "population_value", "replications")) {
    d <- get(dname)
    for (v in intersect(c("condition", "design", "parameter"), names(d))) d[[v]] <- as.character(d[[v]])
    assign(dname, d)
  }
  tkey <- .unique_key(population_value, c("condition", "parameter"))
  rkey <- .unique_key(replications, c("condition", "design", "replication"))
  if (nrow(estimates)) {
    .unique_key(estimates, c("condition", "design", "replication", "parameter"))
    e_run <- match(.key(estimates, c("condition", "design", "replication")), rkey)
    if (anyNA(e_run)) .stop("Every estimate must have a matching attempt in replications.")
    matching_population_value <- match(.key(estimates, c("condition", "parameter")), tkey)
    if (anyNA(matching_population_value)) .stop("Every estimated parameter needs a condition-specific reference value.")
    # The replication record is the sole convergence source for metric calculation.
    usable <- (replications$converged[e_run] %in% TRUE) & is.finite(estimates$estimate)
    estimates <- estimates[usable, , drop = FALSE]
  }
  allowed <- c("ok", "nonconverged", "unknown", "generate_error", "design_error", "fit_error", "import_error")
  if (anyNA(replications$status) || any(!replications$status %in% allowed)) .stop("Unsupported replications$status.")
  if (any((replications$converged %in% TRUE) != (replications$status == "ok")))
    .stop("Only replications with status='ok' may have converged=TRUE, and all ok replications must be TRUE.")
  if (any(is.na(replications$converged) != (replications$status == "unknown")))
    .stop("Only status='unknown' must have converged=NA; failures must be FALSE.")
  if (!all(unique(replications$condition) %in% population_value$condition)) .stop("Missing reference condition.")
  cells <- unique(replications[c("condition", "design")])
  output <- list()
  for (i in seq_len(nrow(cells))) {
    cond <- cells$condition[i]
    design <- cells$design[i]
    rr <- replications[replications$condition == cond & replications$design == design, , drop = FALSE]
    tt <- population_value[population_value$condition == cond, , drop = FALSE]
    for (j in seq_len(nrow(tt))) {
      ee <- estimates[estimates$condition == cond & estimates$design == design &
                        estimates$parameter == tt$parameter[j], , drop = FALSE]
      n <- nrow(ee)
      reference <- tt$value[j]
      error <- ee$estimate - reference
      rbias_excluded <- tt$parameter[j] %in% exclude_rbias
      rbias_defined <- reference != 0
      bias <- if (n) mean(error) else NA_real_
      rmse <- if (n) sqrt(mean(error^2)) else NA_real_
      intervals <- is.finite(ee$lower) & is.finite(ee$upper)
      ni <- sum(intervals)
      cov <- if (ni) mean(ee$lower[intervals] <= reference & ee$upper[intervals] >= reference) else NA_real_
      rejection_rate <- if (ni) mean(ee$lower[intervals] > 0 | ee$upper[intervals] < 0) else NA_real_
      sds <- ee$sd[is.finite(ee$sd)]
      output[[length(output) + 1L]] <- data.frame(condition = cond, design = design,
        parameter = tt$parameter[j], reference = reference,
        relative_bias_defined = rbias_defined, relative_bias_excluded = rbias_excluded, n_attempted = nrow(rr),
        n_fit_returned = sum(rr$status %in% c("ok", "nonconverged", "unknown")),
        n_converged = sum(rr$converged %in% TRUE), n_valid = n, n_interval = ni,
        n_sd = length(sds), convergence_rate = mean(rr$converged %in% TRUE),
        mean_estimate = if (n) mean(ee$estimate) else NA_real_,
        bias = bias, relative_bias = if (!rbias_defined || rbias_excluded) NA_real_ else bias / reference,
        rmse = rmse, empirical_sd = if (n > 1L) stats::sd(ee$estimate) else NA_real_,
        mean_sd = if (length(sds)) mean(sds) else NA_real_,
        coverage = cov,
        power = if (reference != 0) rejection_rate else NA_real_,
        typeI_error = if (reference == 0) rejection_rate else NA_real_,
        stringsAsFactors = FALSE)
    }
  }
  answer <- do.call(rbind, output)
  rownames(answer) <- NULL
  answer
}

screen_designs <- function(performance, parameters, ...,
                           max_abs_relative_bias = 0.10, min_coverage = 0.91,
                           max_coverage = 0.98, min_power = 0.80,
                           min_typeI_error = 0.025, max_typeI_error = 0.075) {
  if (length(list(...)))
    .stop("Unsupported or unnamed screening arguments. Use named max_abs_relative_bias, min_coverage, max_coverage, min_power, min_typeI_error and max_typeI_error arguments.")
  .columns(performance, c("condition", "design", "parameter",
                          "relative_bias", "coverage"))
  .strings(parameters, "parameters")
  if (anyDuplicated(parameters)) .stop("parameters must be unique.")
  if (!nrow(performance)) .stop("performance cannot be empty.")
  .unique_key(performance, c("condition", "design", "parameter"))
  if (!is.null(max_abs_relative_bias)) .scalar_number(max_abs_relative_bias, "max_abs_relative_bias", 0, Inf)
  if (!is.null(min_coverage)) .scalar_number(min_coverage, "min_coverage", 0, 1)
  if (!is.null(max_coverage)) .scalar_number(max_coverage, "max_coverage", 0, 1)
  if (!is.null(min_coverage) && !is.null(max_coverage) && min_coverage > max_coverage)
    .stop("min_coverage must not exceed max_coverage.")
  if (!is.null(min_power)) .scalar_number(min_power, "min_power", 0, 1)
  if (!is.null(min_typeI_error)) .scalar_number(min_typeI_error, "min_typeI_error", 0, 1)
  if (!is.null(max_typeI_error)) .scalar_number(max_typeI_error, "max_typeI_error", 0, 1)
  if (!is.null(min_typeI_error) && !is.null(max_typeI_error) && min_typeI_error > max_typeI_error)
    .stop("min_typeI_error must not exceed max_typeI_error.")
  typeI_screen <- !is.null(min_typeI_error) || !is.null(max_typeI_error)
  rejection_screen <- !is.null(min_power) || typeI_screen
  if (rejection_screen) {
    .columns(performance, "reference")
    if (!is.numeric(performance$reference)) .stop("reference must be numeric.")
    if (!is.null(min_power)) .columns(performance, "power")
    if (typeI_screen) .columns(performance, "typeI_error")
  }
  groups <- unique(performance[c("condition", "design")])
  rows <- lapply(seq_len(nrow(groups)), function(i) {
    p <- performance[performance$condition == groups$condition[i] &
                     performance$design == groups$design[i], , drop = FALSE]
    reasons <- character()
    absent <- setdiff(parameters, p$parameter)
    if (length(absent)) reasons <- c(reasons, paste("Missing parameters:", paste(absent, collapse = ", ")))
    p <- p[p$parameter %in% parameters, , drop = FALSE]
    for (j in seq_len(nrow(p))) {
      z <- p[j, ]
      if ("n_valid" %in% names(z) && (!is.finite(z$n_valid) || z$n_valid < 1))
        reasons <- c(reasons, paste(z$parameter, "no usable converged estimates"))
      if (!is.null(max_abs_relative_bias) &&
          !isTRUE(z$relative_bias_excluded) &&
          (!is.finite(z$relative_bias) || abs(z$relative_bias) > max_abs_relative_bias))
        reasons <- c(reasons, paste(z$parameter, "relative_bias unavailable/exceeds threshold"))
      if (!is.null(min_coverage) || !is.null(max_coverage)) {
        if (!is.finite(z$coverage))
          reasons <- c(reasons, paste(z$parameter, "coverage unavailable for population value"))
        else {
          if (!is.null(min_coverage) && z$coverage < min_coverage)
            reasons <- c(reasons, paste(z$parameter, "coverage below lower bound"))
          if (!is.null(max_coverage) && z$coverage > max_coverage)
            reasons <- c(reasons, paste(z$parameter, "coverage above upper bound"))
        }
      }
      if (rejection_screen) {
        if (!is.finite(z$reference))
          reasons <- c(reasons, paste(z$parameter, "power/typeI_error unavailable for population value"))
        else if (z$reference != 0 && !is.null(min_power)) {
          if (!is.finite(z$power) || z$power < 0 || z$power > 1)
            reasons <- c(reasons, paste(z$parameter, "power unavailable/outside [0,1]"))
          else if (z$power < min_power)
            reasons <- c(reasons, paste(z$parameter, "power below threshold"))
        } else if (z$reference == 0 && typeI_screen) {
          if (!is.finite(z$typeI_error) || z$typeI_error < 0 || z$typeI_error > 1)
            reasons <- c(reasons, paste(z$parameter, "typeI_error unavailable/outside [0,1]"))
          else {
            if (!is.null(min_typeI_error) && z$typeI_error < min_typeI_error)
              reasons <- c(reasons, paste(z$parameter, "typeI_error below lower bound"))
            if (!is.null(max_typeI_error) && z$typeI_error > max_typeI_error)
              reasons <- c(reasons, paste(z$parameter, "typeI_error above upper bound"))
          }
        }
      }
    }
    data.frame(groups[i, ], eligible = !length(reasons), reason = paste(reasons, collapse = "; "),
               stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

# Import existing fitted results; one model and one PSR cutoff per call.
evaluate_pmd <- function(estimates, population_value,
                         exclude_rbias = NULL,
                         source = c("manual", "mplus", "mcmc"), metadata = NULL,
                         n_factors = NULL, cutoff = NULL, map = NULL,
                         burnin = 0, prob = 0.95, mc.cores = 1,
                         max_abs_relative_bias = 0.10, min_coverage = 0.91,
                         max_coverage = 0.98, min_power = 0.80,
                         min_typeI_error = 0.025, max_typeI_error = 0.075,
                         max_iterations = 50000) {
  source <- match.arg(source)
  .check_cores(mc.cores)
  psr_cutoff <- .resolve_psr_cutoff(cutoff, n_factors)
  .columns(population_value, c("parameter", "value"))
  if (!nrow(population_value) || !is.numeric(population_value$value) ||
      any(!is.finite(population_value$value)))
    .stop("population_value must contain finite numeric value and at least one row.")
  population_value$parameter <- as.character(population_value$parameter)
  .strings(population_value$parameter, "population_value$parameter")
  if (!is.null(exclude_rbias)) {
    .strings(exclude_rbias, "exclude_rbias")
    if (anyDuplicated(exclude_rbias) || any(!exclude_rbias %in% population_value$parameter))
      .stop("exclude_rbias must contain unique parameter names from population_value.")
  }
  if (source == "manual") {
    if (!is.null(metadata)) .stop("For manual input, put design and replication directly in estimates; omit metadata.")
    .columns(estimates, c("design", "replication", "parameter", "estimate", "sd", "lower", "upper", "max_psr"))
    if (!nrow(estimates)) .stop("estimates cannot be empty. Retain an NA placeholder row for each failed replication.")
    if (!"condition" %in% names(estimates)) estimates$condition <- "condition1"
    for (v in c("condition", "design", "parameter")) estimates[[v]] <- as.character(estimates[[v]])
    .unique_key(estimates, c("condition", "design", "replication", "parameter"))
    for (v in c("estimate", "sd", "lower", "upper", "max_psr"))
      if (!is.numeric(estimates[[v]])) .stop(v, " must be numeric; use NA_real_ for unavailable values.")
    if (any(estimates$sd < 0, na.rm = TRUE) || any(estimates$lower > estimates$upper, na.rm = TRUE))
      .stop("Invalid SDs or reversed interval bounds.")
    if (any(estimates$max_psr <= 0, na.rm = TRUE))
      .stop("max_psr must be positive numeric values, NA, or positive Inf.")
    manifest <- .validate_manifest(unique(estimates[c("condition", "design", "replication")]))
    manifest_key <- .key(manifest, c("condition", "design", "replication"))
    estimate_key <- .key(estimates, c("condition", "design", "replication"))
    # A single supplied maximum identifies a fit, even when it has many parameter rows.
    # Repeating that same value is allowed; no maximum across replications is taken.
    manifest$max_psr <- vapply(manifest_key, function(k) {
      x <- estimates$max_psr[estimate_key == k]
      x <- unique(x[!is.na(x)])
      if (!length(x)) return(NA_real_)
      if (length(x) != 1L) .stop("Supply one max_psr per replication; repeated nonmissing values must agree.")
      x
    }, numeric(1))
  } else {
    if (source == "mplus") {
      .scalar_number(max_iterations, "max_iterations", 1, .Machine$integer.max, TRUE)
      if (!is.character(estimates) || !length(estimates))
        .stop("Mplus input must be a character vector of .out paths.")
      if (is.null(map)) .stop("Mplus input requires map with parameter and output-row identifiers.")
      .need("MplusAutomation")
    } else {
      if (inherits(estimates, "mcmc.list")) estimates <- list(estimates)
      if (!is.list(estimates) || is.data.frame(estimates) || !length(estimates))
        .stop("MCMC input must be a list of mcmc.list objects, one per replication.")
      .need("coda")
      .scalar_number(burnin, "burnin", 0, .Machine$integer.max, TRUE)
      .scalar_number(prob, "prob", 0, 1)
      if (prob <= 0 || prob >= 1) .stop("prob must be strictly between zero and one.")
    }
    if (is.null(metadata)) .stop("mplus/mcmc input requires metadata with design and replication for every input.")
    .columns(metadata, c("design", "replication"))
    if ("n_factors" %in% names(metadata))
      .stop("Use the single n_factors argument for the shared model; remove n_factors from metadata.")
    if (!"condition" %in% names(metadata)) metadata$condition <- "condition1"
    manifest <- .validate_manifest(metadata)
    if (nrow(manifest) != length(estimates)) .stop("metadata must match the input length and order.")
  }
  # Without condition-specific values, use the same supplied population values in each condition.
  if (!"condition" %in% names(population_value)) {
    .unique_key(population_value, "parameter")
    population_value <- do.call(rbind, lapply(unique(manifest$condition), function(cond)
      data.frame(condition = cond, population_value, stringsAsFactors = FALSE)))
  }
  population_value$condition <- as.character(population_value$condition)
  .unique_key(population_value, c("condition", "parameter"))
  if (!all(manifest$condition %in% population_value$condition)) .stop("Missing population_value condition.")
  processed <- .replication_apply(seq_len(nrow(manifest)), function(i) {
    if (source == "manual") {
      maximum <- manifest$max_psr[i]
      converged <- .psr_pass(maximum, psr_cutoff)
      tab <- estimates[estimate_key == manifest_key[i], , drop = FALSE]
      tab <- .validate_estimates(tab)
      diagnostic <- data.frame(max_psr = maximum, cutoff = psr_cutoff, converged = converged)
    } else if (source == "mplus") {
      tab <- read_mplus_estimates(file = estimates[i], map = map,
                                  cutoff = psr_cutoff, n_factors = n_factors, max_iterations = max_iterations)
      diagnostic <- attr(tab, "mplus_diagnostics")
      diagnostic$cutoff_source <- if (is.null(cutoff)) "factor_default" else "user_override"
      maximum <- diagnostic$last_psr
    } else {
      diagnostic <- mcmc_diagnostics(estimates[[i]], burnin = burnin, prob = prob,
                                     n_factors = n_factors, cutoff = psr_cutoff)
      maximum <- diagnostic$max_psr[1L]
      tab <- .validate_estimates(diagnostic)
    }
    list(estimates = tab, diagnostic = diagnostic, max_psr = maximum)
  }, mc.cores)
  record_rows <- list(); estimate_rows <- list(); diagnostics <- vector("list", nrow(manifest))
  for (i in seq_len(nrow(manifest))) {
    ans <- processed[[i]]
    maximum <- NA_real_; converged <- FALSE; status <- "import_error"
    if (is.null(ans$error)) {
      maximum <- ans$value$max_psr
      diagnostic <- ans$value$diagnostic
      diagnostics[[i]] <- diagnostic
      converged <- isTRUE(diagnostic$converged[1L])
      status <- if (converged) "ok" else "nonconverged"
      tab <- ans$value$estimates
      tab <- tab[tab$parameter %in% population_value$parameter[
        population_value$condition == manifest$condition[i]], , drop = FALSE]
      if (nrow(tab)) estimate_rows[[length(estimate_rows) + 1L]] <- data.frame(
        manifest[rep(i, nrow(tab)), c("condition", "design", "replication"), drop = FALSE],
        tab[c("parameter", "estimate", "sd", "lower", "upper")], max_psr = maximum,
        stringsAsFactors = FALSE)
    }
    record_rows[[i]] <- data.frame(manifest[i, c("condition", "design", "replication"), drop = FALSE],
                                   source = source, status = status, converged = converged, max_psr = maximum,
                                   cutoff = psr_cutoff, n_factors = if (is.null(n_factors)) NA_integer_ else n_factors,
                                   error = if (is.null(ans$error)) "" else ans$error, stringsAsFactors = FALSE)
  }
  returned <- if (length(estimate_rows)) do.call(rbind, estimate_rows) else .empty_results()
  record <- do.call(rbind, record_rows); rownames(record) <- NULL; rownames(returned) <- NULL
  performance <- .evaluate_estimates(returned, population_value, record, exclude_rbias)
  thresholds <- list(max_abs_relative_bias = max_abs_relative_bias, min_coverage = min_coverage,
                     max_coverage = max_coverage, min_power = min_power, min_typeI_error = min_typeI_error,
                     max_typeI_error = max_typeI_error)
  summaries <- lapply(unique(performance$condition), function(cond) {
    p <- performance[performance$condition == cond, , drop = FALSE]
    do.call(screen_designs, c(list(performance = p, parameters = unique(p$parameter)), thresholds))
  })
  summary <- do.call(rbind, summaries); rownames(summary) <- NULL
  matched <- match(.key(performance, c("condition", "design")), .key(summary, c("condition", "design")))
  performance$eligible <- summary$eligible[matched]
  performance$reason <- summary$reason[matched]
  attr(performance, "design_summary") <- summary
  attr(performance, "screening_cutoffs") <- thresholds
  attr(performance, "estimates") <- returned
  attr(performance, "replications") <- record
  attr(performance, "diagnostics") <- diagnostics
  attr(performance, "source") <- source
  class(performance) <- c("pmd_evaluation", "data.frame")
  if (any(record$status == "import_error"))
    warning(sum(record$status == "import_error"),
            " replication(s) could not be read or validated; retained in the denominator. Inspect attr(result, 'replications').",
            call. = FALSE)
  performance
}

# Derive the displayed design list from current rows, so row subsetting stays honest.
print.pmd_evaluation <- function(x, ...) {
  needed <- c("condition", "design", "eligible", "reason")
  if (all(needed %in% names(x))) {
    summary <- unique(as.data.frame(x)[needed])
    cat("PMD designs meeting all active evaluation criteria:\n")
    passed <- summary[summary$eligible %in% TRUE, c("condition", "design"), drop = FALSE]
    if (nrow(passed)) print(passed, row.names = FALSE) else
      cat("None. Inspect reason: a criterion failed or a required result is unavailable.\n")
    cat("Designs are considered acceptable only for the specified scenario and target parameters, under the chosen evaluation criteria.\n\n")
  }
  print.data.frame(x, ...)
  invisible(x)
}
