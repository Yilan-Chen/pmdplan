library(pmdplan)
local({
  err <- function(code, pattern = NULL) {
    x <- tryCatch(force(code), error = identity)
    stopifnot(inherits(x, "error"))
    if (!is.null(pattern)) stopifnot(grepl(pattern, conditionMessage(x), fixed = TRUE))
  }
  abnormal <- "THE MODEL ESTIMATION DID NOT TERMINATE NORMALLY"
  # Independent reference: the supplied nonconvergence expression with configurable limits.
  original_nonconverged <- function(out, cutoff, max_iterations) {
    if (length(out$errors) > 1) {
      if (tail(out$tech8$psr$psr, 1) < cutoff &
          !any(grepl("THE MODEL ESTIMATION DID NOT TERMINATE NORMALLY", unlist(out$errors)))) {
        errors <- FALSE
      } else {
        errors <- TRUE
      }
    } else {
      errors <- FALSE
    }
    is.null(out$tech8$psr) || (nrow(out$tech8$psr) == 0) ||
      (tail(out$tech8$psr$psr, 1) >= cutoff) || errors ||
      (tail(out$tech8$psr$iteration, 1) >= max_iterations)
  }
  # Literal thresholds from the supplied code, checked independently as well.
  original_80000 <- function(out) {
    if (length(out$errors) > 1) {
      if (tail(out$tech8$psr$psr, 1) < 1.1 &
          !any(grepl("THE MODEL ESTIMATION DID NOT TERMINATE NORMALLY", unlist(out$errors)))) {
        errors <- FALSE
      } else {
        errors <- TRUE
      }
    } else {
      errors <- FALSE
    }
    rejected <- is.null(out$tech8$psr) || (nrow(out$tech8$psr) == 0) ||
      (tail(out$tech8$psr$psr, 1) >= 1.1) || errors ||
      (tail(out$tech8$psr$iteration, 1) >= 80000)
    list(converged = !rejected, errors_flag = errors)
  }
  error_lists <- list(list(), list("message"), list(abnormal),
    list(c(abnormal, "other")), list("one", "two"),
    list(abnormal, "other"), list("one", abnormal, "three"))
  count <- 0L
  literal_count <- 0L
  for (cutoff in c(1.05, 1.10)) for (maximum in c(1000, 50000, 80000))
    for (psr in c(cutoff - .001, cutoff, cutoff + .001))
      for (iteration in c(maximum - 1, maximum, maximum + 1))
        for (errors in error_lists) {
          out <- list(tech8 = list(psr = data.frame(
            iteration = c(100, iteration), psr = c(1.3, psr))), errors = errors)
          actual <- mplus_convergence(out, cutoff = cutoff, max_iterations = maximum)
          stopifnot(identical(actual$converged, !original_nonconverged(out, cutoff, maximum)),
            actual$last_psr == psr, actual$last_iteration == iteration,
            actual$max_iterations == maximum,
            actual$iteration_limit_reached == (iteration >= maximum))
          if (cutoff == 1.1 && maximum == 80000) {
            reference <- original_80000(out)
            stopifnot(identical(actual$converged, reference$converged),
              identical(actual$errors_flag, reference$errors_flag))
            literal_count <- literal_count + 1L
          }
          count <- count + 1L
        }
  make_out <- function(iteration = 49999, psr = 1.01, errors = list())
    list(tech8 = list(psr = data.frame(iteration = iteration, psr = psr)), errors = errors)
  stopifnot(mplus_convergence(make_out(), n_factors = 1)$converged,
    mplus_convergence(make_out(), n_factors = 1)$max_iterations == 50000,
    !mplus_convergence(make_out(50000), n_factors = 1)$converged,
    mplus_convergence(make_out(50000), n_factors = 1, max_iterations = 80000)$converged)
  # The rule tests length(errors), not the number of strings after unlisting.
  single <- make_out(errors = list(c(abnormal, "other")))
  stopifnot(mplus_convergence(single, n_factors = 1)$converged,
    !mplus_convergence(single, n_factors = 1)$errors_flag)
  multi <- make_out(errors = list(abnormal, "other"))
  stopifnot(!mplus_convergence(multi, n_factors = 1)$converged,
    mplus_convergence(multi, n_factors = 1)$errors_flag)
  # No extra rejection based on out$converged is added.
  explicit_false <- make_out(); explicit_false$converged <- FALSE
  stopifnot(mplus_convergence(explicit_false, n_factors = 1)$converged)

  for (missing in list(NULL, data.frame(), data.frame(iteration = numeric(), psr = numeric()))) {
    out <- make_out(); out$tech8$psr <- missing
    stopifnot(!mplus_convergence(out, cutoff = 1.1)$converged)
  }
  # Empty results without multiple errors also agree with the literal expression.
  for (empty in list(NULL, data.frame(iteration = numeric(), psr = numeric()))) {
    out <- make_out(); out$tech8$psr <- empty
    stopifnot(identical(mplus_convergence(out, cutoff = 1.1,
      max_iterations = 80000)$converged, original_80000(out)$converged))
    # The original first if() cannot evaluate an empty PSR when errors has length > 1.
    # The package deliberately returns nonconverged instead of stopping here.
    out$errors <- list("one", "two")
    err(original_80000(out))
    stopifnot(!mplus_convergence(out, cutoff = 1.1, max_iterations = 80000)$converged)
  }
  missing <- make_out(psr = NA_real_, errors = list("one", "two"))
  err(original_80000(missing))
  stopifnot(!mplus_convergence(missing, cutoff = 1.1, max_iterations = 80000)$converged)
  for (bad in c(NA_real_, NaN, Inf)) {
    stopifnot(!mplus_convergence(make_out(psr = bad), cutoff = 1.1)$converged,
      !mplus_convergence(make_out(iteration = bad), cutoff = 1.1)$converged)
  }
  for (bad in list(0, -1, 1.5, NA_real_, Inf, "50000", c(50000, 80000))) {
    err(mplus_convergence(make_out(), cutoff = 1.1, max_iterations = bad), "max_iterations")
    err(read_mplus_estimates("absent.out", data.frame(), cutoff = 1.1,
      max_iterations = bad), "max_iterations")
    err(evaluate_pmd("absent.out", data.frame(parameter = "beta", value = .12),
      source = "mplus", cutoff = 1.1, max_iterations = bad), "max_iterations")
  }
  stopifnot(!"policy" %in% names(formals(mplus_convergence)),
    !"policy" %in% names(formals(read_mplus_estimates)))
  err(mplus_convergence(make_out(), cutoff = 1.1, policy = "unused"), "unused argument")

  if (requireNamespace("MplusAutomation", quietly = TRUE)) {
    fixture <- system.file("extdata", "ex9.31.out", package = "MplusAutomation")
    if (nzchar(fixture)) {
      # Adapt only the final checkpoint in a real Bayesian output fixture.
      lines <- readLines(fixture, warn = FALSE)
      idx <- which(grepl("^\\s+2000\\s+1[.]004\\s+9\\s*$", lines))
      stopifnot(length(idx) == 1L)
      capped <- tempfile(fileext = ".out")
      on.exit(unlink(capped), add = TRUE)
      lines[idx] <- sub("2000", "50000", lines[idx], fixed = TRUE)
      writeLines(lines, capped)
      map <- data.frame(parameter = "beta", paramHeader = "SY.ON",
        param = "W", BetweenWithin = "Between")
      read <- read_mplus_estimates(capped, map, n_factors = 1)
      diag <- attr(read, "mplus_diagnostics")
      stopifnot(!read$converged, diag$last_psr == 1.004,
        diag$last_iteration == 50000, diag$iteration_limit_reached, !diag$errors_flag)
      longer <- read_mplus_estimates(capped, map, n_factors = 1, max_iterations = 60000)
      stopifnot(longer$converged,
        attr(longer, "mplus_diagnostics")$max_iterations == 60000)
      metadata <- data.frame(design = "anchor", replication = 1:2)
      values <- data.frame(parameter = "beta", value = .12)
      p <- evaluate_pmd(c(fixture, capped), values, source = "mplus",
        metadata = metadata, map = map, n_factors = 1)
      all_pass <- evaluate_pmd(c(fixture, capped), values, source = "mplus",
        metadata = metadata, map = map, n_factors = 1, max_iterations = 60000)
      stopifnot(p$convergence_rate == .5, p$n_valid == 1,
        all_pass$convergence_rate == 1, all_pass$n_valid == 2,
        attr(p, "diagnostics")[[2]]$last_iteration == 50000,
        attr(all_pass, "diagnostics")[[2]]$max_iterations == 60000)
      stopifnot(identical(all_pass, evaluate_pmd(c(fixture, capped), values,
        source = "mplus", metadata = metadata, map = map, n_factors = 1,
        max_iterations = 60000, mc.cores = 2)))
    }
  }
  stopifnot(count == 378L, literal_count == 63L)
  cat(literal_count, "literal 1.1/80000 comparisons passed.\n")
  cat(count, "reference-rule comparisons, iteration boundaries, missing diagnostics and Mplus import/evaluation propagation passed.\n")
})
