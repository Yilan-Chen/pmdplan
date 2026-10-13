library(pmdplan)
evaluation_error <- function(expr) {
  result <- tryCatch({ force(expr); NULL }, error = identity)
  stopifnot(inherits(result, "error"))
}

# Twenty usable estimates out of forty attempts, with 19/20 intervals covering
# population_value. Removing the rate criterion must not alter any remaining summary.
est <- data.frame(condition = "c", design = "a", replication = 1:20,
  parameter = "theta", estimate = rep(c(1, 3), 10),
  sd = c(0.5, NA_real_, rep(0.25, 18)),
  lower = c(rep(0.5, 19), 2.5), upper = c(rep(4, 19), 3.5))
runs <- data.frame(condition = "c", design = "a", replication = 1:40,
  status = c(rep("ok", 20), rep("fit_error", 20)),
  converged = c(rep(TRUE, 20), rep(FALSE, 20)))
population_value <- data.frame(condition = "c", parameter = "theta", value = 2)
p <- pmdplan:::.evaluate_estimates(est, population_value, runs)
expected <- c("condition", "design", "parameter", "reference",
  "relative_bias_defined", "relative_bias_excluded", "n_attempted", "n_fit_returned", "n_converged",
  "n_valid", "n_interval", "n_sd", "convergence_rate", "mean_estimate",
  "bias", "relative_bias", "rmse", "empirical_sd", "mean_sd", "coverage",
  "power", "typeI_error")
stopifnot(identical(names(p), expected), p$n_attempted == 40,
  p$n_fit_returned == 20, p$n_converged == 20, p$n_valid == 20,
  p$n_interval == 20, p$n_sd == 19, p$convergence_rate == 0.5,
  p$mean_estimate == 2, p$bias == 0, p$relative_bias == 0, p$rmse == 1,
  isTRUE(all.equal(p$empirical_sd, sqrt(20/19))),
  isTRUE(all.equal(p$mean_sd, 5/19)), p$coverage == 0.95,
  p$power == 1, is.na(p$typeI_error))
stopifnot(screen_designs(p, "theta")$eligible,
  screen_designs(p, "theta", max_abs_relative_bias = 0.1)$eligible)

# RMSE is reported without influencing eligibility or being required to screen.
for (rmse_value in c(0, 1e10, NA_real_, Inf)) {
  report_only <- p; report_only$rmse <- rmse_value
  stopifnot(screen_designs(report_only, "theta", max_abs_relative_bias = 0.1)$eligible)
}
report_only$rmse <- NULL
stopifnot(screen_designs(report_only, "theta")$eligible)
evaluation_error(screen_designs(p, "theta", max_rmse = 0.99))
evaluation_error(screen_designs(p, "theta", max_rmse = NULL))

# Removed and positional arguments are rejected rather than silently remapped.
evaluation_error(screen_designs(p, "theta", min_valid_rate = 0.9))
evaluation_error(screen_designs(p, "theta", 0.9, NULL, NULL, 0.05, NULL))
evaluation_error(screen_designs(p, "theta", max_rms = 1))
legacy <- p; legacy$valid_rate <- 0
stopifnot(screen_designs(legacy, "theta")$eligible)

# Finite-point filtering and actual available-result counts are retained.
nonfinite <- est; nonfinite$estimate[1] <- Inf
q <- pmdplan:::.evaluate_estimates(nonfinite, population_value, runs)
stopifnot(identical(names(q), expected), q$n_converged == 20,
  q$n_valid == 19, q$n_interval == 19, q$n_sd == 18,
  q$convergence_rate == 0.5, q$coverage == 18/19)
single <- pmdplan:::.evaluate_estimates(est[1, ], population_value, runs[1, ])
stopifnot(identical(names(single), expected), single$bias == -1,
  single$relative_bias == -0.5, single$rmse == 1,
  is.na(single$empirical_sd), single$mean_sd == 0.5,
  single$coverage == 1)
empty <- pmdplan:::.evaluate_estimates(est[FALSE, ], population_value, runs[21:40, ])
stopifnot(identical(names(empty), expected), empty$n_valid == 0,
  empty$convergence_rate == 0, is.na(empty$mean_estimate),
  is.na(empty$bias), is.na(empty$rmse), is.na(empty$coverage),
  !screen_designs(empty, "theta")$eligible)
cat("Reduced evaluation outputs, retained RMSE and screening without rate or RMSE criteria passed.\n")
