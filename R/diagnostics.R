# Unsplit variance-ratio PSR and pooled posterior summaries.
mcmc_diagnostics <- function(draws, burnin = 0, prob = 0.95,
                             n_factors = NULL, cutoff = NULL) {
  cutoff <- .resolve_psr_cutoff(cutoff, n_factors)
  if (!inherits(draws, "mcmc.list")) .stop("draws must be one coda mcmc.list object per fitted replication.")
  .scalar_number(burnin, "burnin", 0, .Machine$integer.max, TRUE)
  .scalar_number(prob, "prob", 0, 1)
  if (prob <= 0 || prob >= 1) .stop("prob must be strictly between zero and one.")
  chains <- lapply(draws, as.matrix)
  if (!length(chains)) .stop("draws cannot contain zero chains.")
  dims <- lapply(chains, dim)
  if (!all(vapply(dims, identical, logical(1), dims[[1L]])))
    .stop("All chains must have equal stored row and parameter counts.")
  if (nrow(chains[[1L]]) - burnin < 2L || ncol(chains[[1L]]) < 1L)
    .stop("At least two post-burnin stored rows and one parameter are required.")
  nm <- colnames(chains[[1L]])
  .strings(nm, "Chain parameter names")
  if (anyDuplicated(nm)) .stop("Parameter names must be unique.")
  if (!all(vapply(chains, function(z) is.numeric(z) && identical(colnames(z), nm), logical(1))))
    .stop("Chains must be numeric with identical parameter names/order.")
  chains <- lapply(chains, function(z) z[seq.int(burnin + 1L, nrow(z)), , drop = FALSE])
  rows <- lapply(seq_along(nm), function(j) {
    z <- do.call(cbind, lapply(chains, function(ch) ch[, j]))
    n <- nrow(z); m <- ncol(z)
    values <- c(estimate = NA_real_, sd = NA_real_, lower = NA_real_, upper = NA_real_, psr = NA_real_)
    message <- ""
    if (!all(is.finite(z))) message <- "Nonfinite draws: summaries and PSR unavailable."
    else {
      flat <- as.vector(z)
      values[1:4] <- c(stats::median(flat), stats::sd(flat),
        stats::quantile(flat, c((1 - prob)/2, (1 + prob)/2), names = FALSE))
      if (m < 2L) message <- "Only one chain: PSR unavailable."
      else {
        chainmeans <- colMeans(z)
        chainvars <- apply(z, 2L, stats::var)
        W <- mean(chainvars)
        B <- sum((chainmeans - mean(chainmeans))^2) * n / (m - 1)
        varplus <- (n - 1) * W / n + B / n
        values["psr"] <- sqrt(varplus / W)
        if (is.nan(values["psr"])) values["psr"] <- NA_real_
        if (!is.finite(values["psr"])) message <- "Zero within-chain variance: PSR is unavailable or infinite."
      }
    }
    data.frame(parameter = nm[j], as.list(values), chains = m, draws_per_chain = n,
      message = message, stringsAsFactors = FALSE, check.names = FALSE)
  })
  out <- do.call(rbind, rows)
  maximum <- .maximum_psr(out$psr)
  out$max_psr <- maximum
  out$converged <- .psr_pass(maximum, cutoff)
  out$cutoff <- cutoff
  out$n_factors <- if (is.null(n_factors)) NA_integer_ else as.integer(n_factors)
  out
}

.maximum_psr <- function(x) {
  if (!length(x) || anyNA(x)) NA_real_ else max(x)
}

.psr_pass <- function(x, cutoff) is.finite(x) & x > 0 & x < cutoff

mplus_convergence <- function(out, cutoff = NULL, n_factors = NULL,
                              max_iterations = 50000) {
  cutoff_source <- if (is.null(cutoff)) "factor_default" else "user"
  cutoff <- .resolve_psr_cutoff(cutoff, n_factors)
  .scalar_number(max_iterations, "max_iterations", 1, .Machine$integer.max, TRUE)
  psr <- out$tech8$psr
  has_psr <- !is.null(psr) && nrow(psr) > 0L
  last <- if (has_psr) utils::tail(psr$psr, 1L) else NA_real_
  last_iteration <- if (has_psr) utils::tail(psr$iteration, 1L) else NA_real_
  psr_ok <- has_psr && is.finite(last) && last < cutoff
  abnormal <- any(grepl("THE MODEL ESTIMATION DID NOT TERMINATE NORMALLY",
                       unlist(out$errors, use.names = FALSE), fixed = TRUE))
  # Preserve the error-list length condition; do not replace it with any-error rejection.
  errors_flag <- if (length(out$errors) > 1L) !(psr_ok && !abnormal) else FALSE
  iteration_available <- is.finite(last_iteration)
  iteration_limit_reached <- if (iteration_available) last_iteration >= max_iterations else NA
  converged <- psr_ok && !errors_flag && iteration_available && !iteration_limit_reached
  data.frame(converged = converged, last_psr = last, last_iteration = last_iteration,
    errors_flag = errors_flag, terminated_abnormally = abnormal,
    iteration_limit_reached = iteration_limit_reached, max_iterations = max_iterations,
    cutoff = cutoff, n_factors = if (is.null(n_factors)) NA_integer_ else as.integer(n_factors),
    cutoff_source = cutoff_source, stringsAsFactors = FALSE)
}
