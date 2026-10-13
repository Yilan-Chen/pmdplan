library(pmdplan)
rejection_error <- function(expr) {
  result <- tryCatch({ force(expr); NULL }, error = identity)
  stopifnot(inherits(result, "error"))
}

# Two of five usable intervals exclude zero, one in each direction. Touching
# zero does not reject. Missing intervals, nonconvergence and NA estimates do
# not enter the denominator; every attempt still enters convergence_rate.
population_value <- data.frame(condition = "c", parameter = c("zero", "pos", "neg", "tiny", "tinyneg"),
  value = c(0, 2, -2, 1e-12, -1e-12))
est <- do.call(rbind, lapply(population_value$parameter, function(parameter)
  data.frame(condition = "c", design = "a", replication = 1:8, parameter = parameter,
    estimate = c(rep(0.5, 7), NA_real_),
    lower = c(-2, 0.1, -1, 0, -1, NA_real_, 0.1, 0.1),
    upper = c(-0.1, 2, 1, 1, 0, 2, 2, 2))))
runs <- data.frame(condition = "c", design = "a", replication = 1:9,
  status = c(rep("ok", 6), "nonconverged", "ok", "fit_error"),
  converged = c(rep(TRUE, 6), FALSE, TRUE, FALSE))
p <- pmdplan:::.evaluate_estimates(est, population_value, runs)
stopifnot(all(p$n_attempted == 9), all(p$n_converged == 7), all(p$n_valid == 6),
  all(p$n_interval == 5), all(p$convergence_rate == 7/9),
  is.na(p$power[1]), p$typeI_error[1] == 0.4, p$coverage[1] == 0.6,
  all(p$power[-1] == 0.4), all(is.na(p$typeI_error[-1])),
  all(is.finite(p$relative_bias[4:5])))
p_exact <- pmdplan:::.evaluate_estimates(est, population_value, runs, exclude_rbias = c("tiny", "tinyneg"))
stopifnot(identical(p_exact$power, p$power), identical(p_exact$typeI_error, p$typeI_error),
  all(is.na(p_exact$relative_bias[4:5])), all(p_exact$relative_bias_excluded[4:5]))
missing_intervals <- est; missing_intervals$lower <- NA_real_
p_missing <- pmdplan:::.evaluate_estimates(missing_intervals, population_value, runs)
stopifnot(all(p_missing$n_interval == 0), all(is.na(p_missing$power)),
  all(is.na(p_missing$typeI_error)), !screen_designs(p_missing, population_value$parameter)$eligible)
single <- est[est$replication == 2, ]; single$lower <- 0.1; single$upper <- 3
p_single <- pmdplan:::.evaluate_estimates(single, population_value, runs[2, ])
stopifnot(all(p_single$n_interval == 1), p_single$typeI_error[1] == 1,
  all(p_single$power[-1] == 1))
make_rates <- function(reference, rate) data.frame(condition = "c",
  design = paste0("d", seq_along(rate)), parameter = "theta",
  reference = reference, relative_bias = if (reference == 0) NA_real_ else 0,
  relative_bias_excluded = reference == 0,
  coverage = if (reference == 0) 1 - rate else 0.95,
  power = if (reference != 0) rate else NA_real_,
  typeI_error = if (reference == 0) rate else NA_real_)
for (reference in c(1, -1, 1e-12)) {
  rates <- make_rates(reference, c(0.799, 0.80, 1))
  screened <- screen_designs(rates, "theta")
  stopifnot(identical(screened$eligible, c(FALSE, TRUE, TRUE)),
    grepl("power below threshold", screened$reason[1], fixed = TRUE),
    all(screen_designs(rates, "theta", min_power = 0.799)$eligible),
    all(screen_designs(rates, "theta", min_power = NULL)$eligible))
}
rates <- make_rates(0, c(0.024, 0.025, 0.05, 0.075, 0.076))
screened <- screen_designs(rates, "theta")
stopifnot(identical(screened$eligible, c(FALSE, TRUE, TRUE, TRUE, FALSE)),
  grepl("typeI_error below lower bound", screened$reason[1], fixed = TRUE),
  grepl("typeI_error above upper bound", screened$reason[5], fixed = TRUE),
  all(screen_designs(rates, "theta", min_typeI_error = 0.024, max_typeI_error = 0.076)$eligible),
  identical(screen_designs(rates, "theta", min_typeI_error = NULL)$eligible,
    c(TRUE, TRUE, TRUE, TRUE, FALSE)),
  identical(screen_designs(rates, "theta", max_typeI_error = NULL)$eligible,
    c(FALSE, TRUE, TRUE, TRUE, TRUE)),
  all(screen_designs(rates, "theta", min_typeI_error = NULL, max_typeI_error = NULL)$eligible),
  identical(screen_designs(rates, "theta", min_typeI_error = 0.05, max_typeI_error = 0.05)$eligible,
    c(FALSE, FALSE, TRUE, FALSE, FALSE)))
for (bound in c("min_power", "min_typeI_error", "max_typeI_error")) {
  for (bad in list(-0.01, 1.01, Inf, NA_real_, NaN, "0.8", c(0.1, 0.2))) {
    args <- list(performance = rates, parameters = "theta")
    args[bound] <- list(bad)
    rejection_error(do.call(screen_designs, args))
  }
}
rejection_error(screen_designs(rates, "theta", min_typeI_error = 0.08, max_typeI_error = 0.07))

# Only the metric appropriate to the population_value is required to have a finite value.
for (bad in c(NA_real_, NaN, Inf, -0.01, 1.01)) {
  pos <- make_rates(1, bad)
  stopifnot(!screen_designs(pos, "theta")$eligible,
    screen_designs(pos, "theta", min_power = NULL)$eligible)
  zero <- make_rates(0, bad); zero$coverage <- 0.95
  stopifnot(!screen_designs(zero, "theta")$eligible,
    screen_designs(zero, "theta", min_typeI_error = NULL, max_typeI_error = NULL)$eligible)
}
pos <- make_rates(1, 0.8); pos$typeI_error <- Inf
zero <- make_rates(0, 0.05); zero$power <- Inf
stopifnot(screen_designs(pos, "theta")$eligible, screen_designs(zero, "theta")$eligible)
pos$reference <- NA_real_
stopifnot(!screen_designs(pos, "theta")$eligible)
pos$reference <- "unknown"
rejection_error(screen_designs(pos, "theta"))
old <- make_rates(1, 0.8); old[c("power", "typeI_error", "reference")] <- NULL
rejection_error(screen_designs(old, "theta"))
stopifnot(screen_designs(old, "theta", min_power = NULL,
  min_typeI_error = NULL, max_typeI_error = NULL)$eligible)

# All selected parameters must pass their own applicable criterion.
mixed <- rbind(make_rates(1, 0.8), make_rates(0, 0.05))
mixed$parameter <- c("effect", "null")
stopifnot(screen_designs(mixed, c("effect", "null"))$eligible)
mixed$power[1] <- 0.799
stopifnot(!screen_designs(mixed, c("effect", "null"))$eligible)
mixed$power[1] <- 0.8; mixed$typeI_error[2] <- 0.076
stopifnot(!screen_designs(mixed, c("effect", "null"))$eligible)
mixed$typeI_error[2] <- 0.05
mixed$relative_bias_excluded[2] <- FALSE
stopifnot(!screen_designs(mixed, c("effect", "null"), max_abs_relative_bias = 0.1)$eligible)
cat("Interval rejection, exact-zero classification, power/type I error cutoffs and mixed-parameter screening passed.\n")
