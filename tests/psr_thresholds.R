library(pmdplan)
expect_psr_error <- function(expr) {
  result <- tryCatch({ force(expr); NULL }, error = identity)
  stopifnot(inherits(result, "error"))
}
psr_result <- function(value) {
  table <- if (is.numeric(value) && length(value))
    data.frame(iteration = seq_along(value) * 100, psr = value) else value
  list(tech8 = list(psr = table), errors = list())
}
  for (nf in c(0, 1, 2, 5)) {
    limit <- if (nf == 1) 1.05 else 1.10
    below <- mplus_convergence(psr_result(limit - 0.001), n_factors = nf)
    equal <- mplus_convergence(psr_result(limit), n_factors = nf)
    above <- mplus_convergence(psr_result(limit + 0.001), n_factors = nf)
    stopifnot(below$converged, !equal$converged, !above$converged,
      below$cutoff == limit, below$n_factors == nf, below$cutoff_source == "factor_default")
    override <- mplus_convergence(psr_result(1.04), n_factors = nf, cutoff = 1.03)
    stopifnot(!override$converged, override$cutoff == 1.03, override$cutoff_source == "user")
  }
custom <- mplus_convergence(psr_result(1.11), cutoff = 1.12)
stopifnot(custom$converged, custom$cutoff == 1.12, is.na(custom$n_factors), custom$cutoff_source == "user")
stopifnot(mplus_convergence(psr_result(1.04), cutoff = 1.05)$converged)
# Earlier PSR values do not replace the final value; iterations are below the limit.
stopifnot(mplus_convergence(psr_result(c(1.3, 1.04)), n_factors = 1)$converged)
for (value in list(NULL, data.frame(), NA_real_, Inf, c(1.01, NA_real_)))
  stopifnot(!mplus_convergence(psr_result(value), n_factors = 1)$converged)
expect_psr_error(mplus_convergence(psr_result(1.02)))
for (nf in list(-1, 1.5, NA_real_, Inf, "1", c(1,2)))
  expect_psr_error(mplus_convergence(psr_result(1.02), n_factors = nf))
for (limit in list(0.9, NA_real_, Inf, "1.05", c(1.05,1.1)))
  expect_psr_error(mplus_convergence(psr_result(1.02), cutoff = limit))
# Invalid threshold setup is rejected before attempting Mplus file reading.
expect_psr_error(read_mplus_estimates("does-not-exist.out", data.frame()))

# Exercise the real importer with a bundled MplusAutomation example output.
# Bayesian output uses the fixed columns and propagates the chosen cutoff.
if (requireNamespace("MplusAutomation", quietly = TRUE)) {
  fixture <- system.file("extdata", "ex9.31.out", package = "MplusAutomation")
  if (nzchar(fixture)) {
    map <- data.frame(parameter = "beta", paramHeader = "SY.ON", param = "W", BetweenWithin = "Between")
    one <- read_mplus_estimates(fixture, map, n_factors = 1)
    two <- read_mplus_estimates(fixture, map, n_factors = 2)
    override <- read_mplus_estimates(fixture, map, n_factors = 1, cutoff = 1.03)
    stopifnot(attr(one, "mplus_diagnostics")$cutoff == 1.05,
      attr(two, "mplus_diagnostics")$cutoff == 1.10,
      attr(override, "mplus_diagnostics")$cutoff == 1.03,
      attr(override, "mplus_diagnostics")$cutoff_source == "user",
      identical(one$estimate, two$estimate), one$converged,
      abs(one$estimate - .12) < 1e-12)
    cat("Mplus estimate importer threshold propagation passed using a bundled output fixture.\n")
  }
  # Bayesian summaries require posterior_sd and both CI columns; ML se is insufficient.
  ml_fixture <- system.file("extdata", "ex5.1.out", package = "MplusAutomation")
  if (nzchar(ml_fixture)) {
    map <- data.frame(parameter = "loading_y2", paramHeader = "F1.BY", param = "Y2")
    failure <- tryCatch(read_mplus_estimates(ml_fixture, map, n_factors = 1), error = identity)
    stopifnot(inherits(failure, "error"),
      grepl("Missing columns: posterior_sd, lower_2.5ci, upper_2.5ci",
        conditionMessage(failure), fixed = TRUE))
    result <- suppressWarnings(evaluate_pmd(ml_fixture,
      data.frame(parameter = "loading_y2", value = 1), source = "mplus",
      metadata = data.frame(design = "anchor", replication = 1), map = map, n_factors = 1))
    stopifnot(result$convergence_rate == 0, result$n_attempted == 1,
      attr(result, "replications")$status == "import_error")
  }
}
cat("Factor-specific PSR defaults, custom cutoffs and boundary tests passed.\n")
