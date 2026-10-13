library(pmdplan)
local({
  err <- function(code, pattern = NULL) {
    x <- tryCatch(force(code), error = identity)
    stopifnot(inherits(x, "error"))
    if (!is.null(pattern)) stopifnot(grepl(pattern, conditionMessage(x), fixed = TRUE))
  }
  d <- data.frame(condition = "c", design = "anchor", replication = 1:4,
    parameter = "theta", estimate = c(1, 3, 99, 99), sd = 1,
    lower = c(0, 2.5, 0, 0), upper = c(2, 4, 1, 1), max_psr = c(1.01, 1.04, 1.05, NA))
  population_value <- data.frame(condition = "c", parameter = "theta", value = 2)
  # Keep the completely failed fifth replication in the estimate table itself.
  d <- rbind(d, data.frame(condition = "c", design = "anchor", replication = 5,
    parameter = "theta", estimate = NA_real_, sd = NA_real_,
    lower = NA_real_, upper = NA_real_, max_psr = NA_real_))
  x <- evaluate_pmd(d, population_value, n_factors = 1)
  stopifnot(!"converged" %in% names(attr(x, "estimates")), x$convergence_rate == 2/5, x$n_attempted == 5, x$n_valid == 2,
    x$bias == 0, x$rmse == 1, x$coverage == 0.5,
    attr(x, "replications")$converged[3] == FALSE,
    all(attr(x, "replications")$cutoff == 1.05))
  for (nf in c(2, 3, 5)) {
    other <- evaluate_pmd(d, population_value, n_factors = nf)
    stopifnot(other$convergence_rate == 3/5, all(attr(other, "replications")$cutoff == 1.10))
  }
  override <- evaluate_pmd(d, population_value, cutoff = 1.04)
  stopifnot(override$convergence_rate == 1/5)
  unavailable <- evaluate_pmd(d[5, , drop = FALSE], population_value, cutoff = 1.10)
  stopifnot(unavailable$n_attempted == 1, unavailable$convergence_rate == 0, unavailable$n_valid == 0)
  d$converged <- TRUE
  stopifnot(identical(evaluate_pmd(d, population_value, n_factors = 1), x))
  bad <- d; bad$max_psr[1] <- -1
  err(evaluate_pmd(bad, population_value, n_factors = 1), "max_psr")
  err(evaluate_pmd(d, population_value), "n_factors")
  err(evaluate_pmd(d[, setdiff(names(d), "max_psr")], population_value, cutoff = 1.1), "max_psr")
  err(evaluate_pmd(rbind(d, d[1, ]), population_value, cutoff = 1.1), "Duplicate")
  bad <- d; bad$sd[1] <- -1
  err(evaluate_pmd(bad, population_value, cutoff = 1.1), "Invalid SDs")
  bad <- d; bad$replication[1] <- 1.5
  err(evaluate_pmd(bad, population_value, cutoff = 1.1), "replication")
  {
    multi <- evaluate_pmd(d, population_value, n_factors = 1, mc.cores = 2)
    stopifnot(identical(x, multi))
  }
  err(evaluate_pmd(d, population_value, n_factors = 1, mc.cores = 0), "mc.cores")

  if (requireNamespace("coda", quietly = TRUE)) {
    samples <- coda::mcmc.list(coda::mcmc(cbind(theta = 1:4)), coda::mcmc(cbind(theta = 2:5)))
    diag <- mcmc_diagnostics(samples, n_factors = 1)
    stopifnot(abs(diag$psr - sqrt(1.05)) < 1e-12, diag$estimate == 3,
      abs(diag$sd - sqrt(12/7)) < 1e-12, abs(diag$lower - 1.175) < 1e-12,
      abs(diag$upper - 4.825) < 1e-12, diag$converged,
      !any(grepl("^(ess|mcse|rhat|psrf)", names(diag))))
    identical_chains <- coda::mcmc.list(samples[[1]], samples[[1]])
    stopifnot(abs(mcmc_diagnostics(identical_chains, cutoff = 1.05)$psr - sqrt(.75)) < 1e-12)
    meta <- data.frame(condition = "c", design = "matrix", replication = 1:3)
    chain_input <- list(samples, identical_chains, NULL)
    post <- suppressWarnings(evaluate_pmd(chain_input, population_value, source = "mcmc", metadata = meta, n_factors = 1))
    stopifnot(!"converged" %in% names(attr(post, "estimates")), post$convergence_rate == 2/3, post$n_attempted == 3, post$n_valid == 2,
      attr(post, "replications")$status[3] == "import_error")
    # A poorly mixed parameter excluded from population_value must still control whole-fit PSR.
    bad_chains <- coda::mcmc.list(coda::mcmc(cbind(theta = 1:4, nuisance = 1:4)),
      coda::mcmc(cbind(theta = 2:5, nuisance = 101:104)))
    fail <- evaluate_pmd(bad_chains, population_value, source = "mcmc", metadata = meta[1, ], cutoff = 1.1)
    stopifnot(fail$convergence_rate == 0, attr(fail, "replications")$max_psr > 1.1)
    one <- mcmc_diagnostics(coda::mcmc.list(samples[[1]]), cutoff = 1.1)
    stopifnot(is.na(one$psr), !one$converged, is.finite(one$estimate))
    const <- coda::mcmc.list(coda::mcmc(cbind(theta = rep(1, 4))), coda::mcmc(cbind(theta = rep(1, 4))))
    stopifnot(is.na(mcmc_diagnostics(const, cutoff = 1.1)$max_psr))
    nonfinite <- samples; nonfinite[[1]][1, 1] <- NA_real_
    stopifnot(!mcmc_diagnostics(nonfinite, cutoff = 1.1)$converged)
    err(mcmc_diagnostics(samples, burnin = 3, cutoff = 1.1), "At least two")
    stopifnot(identical(post,
      suppressWarnings(evaluate_pmd(chain_input, population_value, source = "mcmc", metadata = meta, n_factors = 1, mc.cores = 2))))
  }
  if (requireNamespace("MplusAutomation", quietly = TRUE)) {
    fixture <- system.file("extdata", "ex9.31.out", package = "MplusAutomation")
    if (nzchar(fixture)) {
      map <- data.frame(parameter = "beta", paramHeader = "SY.ON", param = "W", BetweenWithin = "Between")
      md <- data.frame(condition = "c", design = "anchor", replication = 1:2)
      target <- data.frame(condition = "c", parameter = "beta", value = .12)
      mp <- suppressWarnings(evaluate_pmd(c(fixture, paste0(fixture, ".absent")), target,
        source = "mplus", metadata = md, map = map, n_factors = 1))
      raw <- attr(mp, "estimates")
      stopifnot(!"converged" %in% names(raw), mp$n_attempted == 2, mp$convergence_rate == .5,
        raw$estimate == .12, raw$sd == .016, raw$lower == .09, raw$upper == .151,
        attr(mp, "replications")$status[2] == "import_error",
        attr(mp, "diagnostics")[[1]]$cutoff_source == "factor_default")
      stopifnot(identical(mp,
        suppressWarnings(evaluate_pmd(c(fixture, paste0(fixture, ".absent")), target,
          source = "mplus", metadata = md, map = map, n_factors = 1, mc.cores = 2))))
    }
  }
  stopifnot(!exists("run_pmd_simulation", asNamespace("pmdplan"), inherits = FALSE),
    !exists("run_mplus", asNamespace("pmdplan"), inherits = FALSE))
  cat("Three input routes, PSR, missing results, exact thresholds and replication parallelism passed.\n")
})
