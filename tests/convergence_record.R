library(pmdplan)
local({
  err <- function(code) stopifnot(inherits(tryCatch(force(code), error=identity), "error"))
  # Reuse replication IDs across both designs and conditions; reorder both tables.
  runs <- expand.grid(replication=1:3, design=c("a", "b"), condition=c("c1", "c2"),
    stringsAsFactors=FALSE)
  runs$converged <- c(TRUE, TRUE, FALSE, FALSE, TRUE, FALSE,
    FALSE, FALSE, TRUE, FALSE, FALSE, FALSE)
  runs$status <- ifelse(runs$converged, "ok", "nonconverged")
  runs$status[12] <- "import_error"
  targets <- expand.grid(condition=c("c1", "c2"), parameter=c("theta", "eta"),
    stringsAsFactors=FALSE)
  targets$value <- 1
  estimates <- do.call(rbind, lapply(1:11, function(i)
    data.frame(runs[rep(i, 2), c("condition", "design", "replication")],
      parameter=c("theta", "eta"), estimate=c(10*i, -10*i), sd=1,
      lower=c(10*i-1, -10*i-1), upper=c(10*i+1, -10*i+1))))
  estimates$estimate[4] <- NA_real_  # eta in c1/a/2: fit converged, point unavailable
  estimates$sd[3] <- NA_real_       # theta in c1/a/2: point usable, SD unavailable
  estimates$lower[3] <- NA_real_    # theta in c1/a/2: interval unavailable
  canonical <- function(x) {
    x <- x[order(x$condition, x$design, x$parameter), , drop=FALSE]
    rownames(x) <- NULL
    x
  }
  baseline <- pmdplan:::.evaluate_estimates(estimates, targets, runs)
  reordered <- pmdplan:::.evaluate_estimates(estimates[nrow(estimates):1, ],
    targets[nrow(targets):1, ], runs[c(12, 1:11), ])
  stopifnot(identical(canonical(baseline), canonical(reordered)))
  a <- subset(baseline, condition=="c1" & design=="a")
  theta <- subset(a, parameter=="theta")
  eta <- subset(a, parameter=="eta")
  stopifnot(theta$n_attempted==3, theta$n_converged==2, theta$n_valid==2,
    theta$convergence_rate==2/3, theta$mean_estimate==15, theta$bias==14,
    theta$n_interval==1, theta$n_sd==1,
    eta$n_converged==2, eta$n_valid==1, eta$mean_estimate== -10)
  stopifnot(subset(baseline, condition=="c1" & design=="b" & parameter=="theta")$mean_estimate==50,
    subset(baseline, condition=="c2" & design=="a" & parameter=="theta")$mean_estimate==90)
  none <- subset(baseline, condition=="c2" & design=="b")
  stopifnot(all(none$n_attempted==3), all(none$convergence_rate==0),
    all(none$n_valid==0), all(is.na(none$bias)))
  # Obsolete parameter-level flags cannot override the authoritative run record.
  for (flag in list(TRUE, FALSE, NA, "obsolete")) {
    stale <- estimates; stale$converged <- flag
    stopifnot(identical(baseline, pmdplan:::.evaluate_estimates(stale, targets, runs)))
  }
  broken <- runs; broken$converged[1] <- FALSE
  err(pmdplan:::.evaluate_estimates(estimates, targets, broken))
  err(pmdplan:::.evaluate_estimates(estimates, targets, runs[-1, ]))
  validated <- pmdplan:::.validate_estimates(data.frame(parameter="theta", estimate=1,
    sd=.1, lower=.8, upper=1.2))
  stopifnot(identical(names(validated), c("parameter", "estimate", "sd", "lower", "upper")))
  # The public manual route computes convergence once and omits it from estimates.
  manual <- data.frame(design="a", replication=rep(1:2, each=2),
    parameter=rep(c("theta", "eta"), 2), estimate=c(1, 2, 999, 999),
    sd=.1, lower=0, upper=1000, max_psr=rep(c(1.01, 1.2), each=2), converged=TRUE)
  result <- evaluate_pmd(manual, data.frame(parameter=c("theta", "eta"), value=c(1, 2)),
    cutoff=1.1)
  stopifnot(!"converged" %in% names(attr(result, "estimates")),
    identical(attr(result, "replications")$converged, c(TRUE, FALSE)),
    all(result$convergence_rate==.5), identical(result$mean_estimate, c(1, 2)))
  if (requireNamespace("coda", quietly=TRUE)) {
    empty <- suppressWarnings(evaluate_pmd(list(NULL), data.frame(parameter="theta", value=1),
      source="mcmc", metadata=data.frame(design="a", replication=1), cutoff=1.1))
    stopifnot(nrow(attr(empty, "estimates"))==0,
      !"converged" %in% names(attr(empty, "estimates")),
      !attr(empty, "replications")$converged, empty$n_attempted==1,
      empty$convergence_rate==0)
  }
  cat("Single convergence record, composite-key matching, per-parameter denominators and empty results passed.\n")
})
