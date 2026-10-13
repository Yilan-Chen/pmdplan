library(pmdplan)
coverage_error <- function(expr) {
  result <- tryCatch({ force(expr); NULL }, error = identity)
  stopifnot(inherits(result, "error"))
}
make_performance <- function(coverage) data.frame(
  condition = "c", design = paste0("d", seq_along(coverage)), parameter = "theta",
  relative_bias = 0,
  reference = 1, power = 1, typeI_error = NA_real_,
  coverage = coverage)
p <- make_performance(c(0.909, 0.91, 0.95, 0.98, 0.981))
s <- screen_designs(p, "theta")
stopifnot(identical(s$eligible, c(FALSE, TRUE, TRUE, TRUE, FALSE)),
  grepl("below lower bound", s$reason[1], fixed = TRUE),
  grepl("above upper bound", s$reason[5], fixed = TRUE))
# Custom endpoints are inclusive; a single-point accepted range is also valid.
s <- screen_designs(p, "theta", min_coverage = 0.909, max_coverage = 0.981)
stopifnot(all(s$eligible))
s <- screen_designs(p, "theta", min_coverage = 0.95, max_coverage = 0.95)
stopifnot(identical(s$eligible, c(FALSE, FALSE, TRUE, FALSE, FALSE)))
# Bounds can be enabled and disabled independently.
stopifnot(identical(screen_designs(p, "theta", min_coverage = NULL)$eligible,
                    c(TRUE, TRUE, TRUE, TRUE, FALSE)),
  identical(screen_designs(p, "theta", max_coverage = NULL)$eligible,
            c(FALSE, TRUE, TRUE, TRUE, TRUE)),
  all(screen_designs(p, "theta", min_coverage = NULL, max_coverage = NULL)$eligible))
for (bad in list(-0.01, 1.01, Inf, NA_real_, NaN, "0.95", c(0.91, 0.98))) {
  coverage_error(screen_designs(p, "theta", min_coverage = bad))
  coverage_error(screen_designs(p, "theta", max_coverage = bad))
}
coverage_error(screen_designs(p, "theta", min_coverage = 0.99, max_coverage = 0.98))
for (missing in c(NA_real_, NaN, Inf)) {
  q <- make_performance(missing)
  stopifnot(!screen_designs(q, "theta")$eligible,
    !screen_designs(q, "theta", min_coverage = NULL)$eligible,
    !screen_designs(q, "theta", max_coverage = NULL)$eligible,
    screen_designs(q, "theta", min_coverage = NULL, max_coverage = NULL)$eligible)
}
# All target parameters and other enabled criteria must pass simultaneously.
q <- make_performance(c(0.95, 0.99)); q$design <- "same"
q$parameter <- c("theta1", "theta2")
stopifnot(!screen_designs(q, c("theta1", "theta2"))$eligible)
q$coverage <- 0.95; q$relative_bias <- c(-0.1, 0.1)
stopifnot(screen_designs(q, c("theta1", "theta2"), max_abs_relative_bias = 0.1)$eligible)
q$relative_bias[2] <- 0.101
stopifnot(!screen_designs(q, c("theta1", "theta2"), max_abs_relative_bias = 0.1)$eligible)
q$relative_bias <- 0
stopifnot(screen_designs(q, c("theta1", "theta2"))$eligible)
cat("Coverage defaults, inclusive boundaries, custom ranges and disabled bounds passed.\n")
