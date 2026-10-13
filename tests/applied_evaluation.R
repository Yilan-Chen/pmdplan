library(pmdplan)
local({
  err <- function(code, pattern) {
    e <- tryCatch(force(code), error = identity)
    stopifnot(inherits(e, "error"), grepl(pattern, conditionMessage(e), fixed = TRUE))
  }
  # One scenario, two designs: 19/20 coverage passes; 18/20 fails.
  pv <- data.frame(parameter = "beta", value = 1)
  one <- data.frame(design = "anchor", replication = 1:20, parameter = "beta",
    estimate = 1, sd = .1, lower = c(rep(.8, 19), 1.1), upper = 1.2, max_psr = 1.01)
  two <- one; two$design <- "matrix"; two$lower[19] <- 1.1
  e <- rbind(one, two)
  p <- evaluate_pmd(e, pv, cutoff = 1.05, max_abs_relative_bias = .1)
  s <- attr(p, "design_summary")
  stopifnot(inherits(p, "pmd_evaluation"), is.data.frame(p),
    all(p$condition == "condition1"), all(is.na(attr(p, "replications")$n_factors)),
    identical(s$eligible, c(TRUE, FALSE)), identical(p$eligible, s$eligible),
    p$coverage[1] == .95, p$coverage[2] == .9,
    identical(attr(p, "screening_cutoffs")$max_abs_relative_bias, .1),
    all(attr(p, "replications")$cutoff == 1.05),
    is.null(attr(p, "runs")))
  txt <- paste(capture.output(print(p)), collapse = "\n")
  stopifnot(grepl("PMD designs meeting all active evaluation criteria", txt, fixed = TRUE),
    grepl("anchor", txt, fixed = TRUE))
  txt <- paste(capture.output(print(p[p$design == "matrix", ])), collapse = "\n")
  stopifnot(grepl("None.", txt, fixed = TRUE), !grepl("anchor", txt, fixed = TRUE))
  for (nf in c(1, 2, 3, 8)) {
    f <- evaluate_pmd(e, pv, n_factors = nf)
    stopifnot(all(attr(f, "replications")$cutoff == if (nf == 1) 1.05 else 1.10))
  }
  err(evaluate_pmd(e, pv), "n_factors")
  err(evaluate_pmd(e, pv, cutoff = 1.05, runs = data.frame()), "unused argument")
  err(evaluate_pmd(e, pv, cutoff = 1.05, zero_tolerance = 0), "unused argument")
  err(evaluate_pmd(e, pv, cutoff = 1.05, exclude_rbias = "misspelled"), "exclude_rbias")
  err(evaluate_pmd(e, pv, cutoff = 1.05, min_coverage = .99, max_coverage = .98), "min_coverage")

  # A single maximum per fit is independent of row order and number of parameters.
  many <- one[1:4, ]; many$parameter <- "beta"
  second <- many; second$parameter <- "other"; second$max_psr <- NA_real_
  many$max_psr <- c(1.01, 1.05, Inf, NA_real_)
  both <- rbind(many, second)[c(5, 1, 6, 2, 7, 3, 8, 4), ]
  targets <- data.frame(parameter = c("beta", "other"), value = 1)
  a <- evaluate_pmd(both, targets, cutoff = 1.05)
  stopifnot(all(a$n_attempted == 4), all(a$n_valid == 1),
    all(a$convergence_rate == .25),
    identical(attr(a, "replications")$converged, c(TRUE, FALSE, FALSE, FALSE)))
  repeated <- both
  key <- match(repeated$replication, many$replication)
  repeated$max_psr <- many$max_psr[key]
  stopifnot(identical(a, evaluate_pmd(repeated, targets, cutoff = 1.05)))
  conflict <- repeated; conflict$max_psr[1] <- 1.02
  err(evaluate_pmd(conflict, targets, cutoff = 1.05), "one max_psr per replication")

  # User exclusion changes only relative bias and its eligibility criterion.
  null <- one; null$parameter <- "null"; null$estimate <- .01
  null$lower <- c(rep(-.1, 19), .01); null$upper <- .1
  combined <- rbind(one, null)
  pv2 <- data.frame(parameter = c("beta", "null"), value = c(1, 0))
  noex <- evaluate_pmd(combined, pv2, cutoff = 1.05, max_abs_relative_bias = .1)
  ex <- evaluate_pmd(combined, pv2, cutoff = 1.05,
    max_abs_relative_bias = .1, exclude_rbias = "null")
  stopifnot(!any(noex$eligible), all(ex$eligible),
    ex$relative_bias_excluded[2], !ex$relative_bias_defined[2],
    is.na(ex$relative_bias[2]), ex$typeI_error[2] == .05,
    identical(ex$coverage, noex$coverage), identical(ex$power, noex$power),
    identical(ex$typeI_error, noex$typeI_error), identical(ex$rmse, noex$rmse))
  tiny <- pv; tiny$value <- 1e-12
  t <- evaluate_pmd(one, tiny, cutoff = 1.05)
  stopifnot(is.finite(t$relative_bias), t$relative_bias_defined)
  t2 <- evaluate_pmd(one, tiny, cutoff = 1.05, exclude_rbias = "beta")
  stopifnot(is.na(t2$relative_bias), t2$relative_bias_excluded,
    identical(t$rmse, t2$rmse), identical(t$power, t2$power))

  # Default values apply to each condition; explicit target sets may differ.
  c1 <- one; c1$condition <- "N60_T20"
  c2 <- one; c2$condition <- "N80_T30"; c2$parameter <- "other"
  pvm <- data.frame(condition = c("N60_T20", "N80_T30"),
    parameter = c("beta", "other"), value = 1)
  separate <- evaluate_pmd(rbind(c1, c2), pvm, cutoff = 1.05)
  stopifnot(all(separate$eligible), nrow(attr(separate, "design_summary")) == 2)
  c2$parameter <- "beta"
  shared <- evaluate_pmd(rbind(c1, c2), pv, cutoff = 1.05)
  stopifnot(all(shared$eligible), all(shared$reference == 1))

  failed <- one[1, ]; failed[, c("estimate", "sd", "lower", "upper", "max_psr")] <- NA_real_
  nofit <- evaluate_pmd(failed, pv, cutoff = 1.05,
    min_coverage = NULL, max_coverage = NULL, min_power = NULL,
    min_typeI_error = NULL, max_typeI_error = NULL)
  stopifnot(!nofit$eligible, nofit$convergence_rate == 0, nofit$n_attempted == 1,
    grepl("no usable converged estimates", nofit$reason, fixed = TRUE))

  if (requireNamespace("coda", quietly = TRUE)) {
    # Skewed chains distinguish the posterior median (0) from its mean (2).
    chain <- coda::mcmc(cbind(beta = c(0, 0, 0, 8)))
    draws <- coda::mcmc.list(chain, chain)
    meta <- data.frame(design = "anchor", replication = 1:2)
    post <- evaluate_pmd(list(draws, draws), pv, source = "mcmc",
      metadata = meta, cutoff = 1.05)
    raw <- attr(post, "estimates")
    stopifnot(all(raw$estimate == 0), post$mean_estimate == 0,
      all(abs(attr(post, "replications")$max_psr - sqrt(.75)) < 1e-12),
      all(raw$sd == stats::sd(rep(c(0, 0, 0, 8), 2))))
    diag <- mcmc_diagnostics(draws, cutoff = 1.05, prob = .5)
    stopifnot(diag$lower == 0, diag$upper == 2, diag$estimate == 0)
    meta$n_factors <- c(1, 2)
    err(evaluate_pmd(list(draws, draws), pv, source = "mcmc",
      metadata = meta, cutoff = 1.05), "single n_factors")
  }
  cat("Applied evaluation: optional conditions, per-fit PSR, posterior medians, explicit rbias exclusions and automatic design screening passed.\n")
})
