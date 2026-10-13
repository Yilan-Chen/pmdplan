library(pmdplan)
if (requireNamespace("lavaan",quietly=TRUE)) {
  set.seed(443)
  d <- expand.grid(time=1:8,id=1:150)
  factors <- list(Y=paste0("y",1:4),X=paste0("x",1:4))
  for(f in names(factors)) {
    between <- rnorm(150)
    within <- rnorm(nrow(d))
    for(j in 1:4) d[[factors[[f]][j]]] <- (0.4+j/10)*(between[d$id]+within)+
      rnorm(150,sd=0.5)[d$id]+rnorm(nrow(d),sd=0.7)
  }
  d$id <- sprintf("participant%03d", d$id)
  d$time <- as.Date("2026-01-01") + d$time
  a <- pmd_forms(d,"id","time",factors=factors,n_subsets=4,subsets_per_form=3,
    design="anchor",cfa_type = "twolevel",seed=15)
  b <- pmd_forms(d,"id","time",factors=factors,n_subsets=4,subsets_per_form=3,
    design="anchor",anchors=a$specification$anchors,seed=15)
  stopifnot(nrow(a$loadings)==8,all(is.finite(a$loadings$loading)),identical(a$mask,b$mask),
    length(a$specification$anchors)==2,all(!a$mask[,a$specification$anchors]),
    !a$specification$anchor_fallback, is.null(a$specification$cfa_failure),
    a$specification$loading_source == "data", b$specification$loading_source == "manual")
  stopifnot(a$specification$cfa_type == "twolevel", all(a$loadings$level == "within"))
  stopifnot(identical(a$data$id, d$id), identical(a$data$time, d$time))
  single <- pmd_forms(d,"id","time",factors=factors,n_subsets=4,subsets_per_form=3,
    design="anchor",cfa_type="singlelevel",seed=15)
  manual <- pmd_forms(d,"id","time",factors=factors,n_subsets=4,subsets_per_form=3,
    design="anchor",anchors=single$specification$anchors,seed=15)
  stopifnot(!single$specification$anchor_fallback, nrow(single$loadings) == 8,
    all(is.finite(single$loadings$loading)), all(single$loadings$level == "single"),
    single$specification$cfa_type == "singlelevel", identical(single$mask, manual$mask))
  # Single-level CFA does not use the participant clustering variable.
  one <- d
  one$id <- 1L
  one$time <- seq_len(nrow(one))
  pooled <- pmd_forms(one,"id","time",factors=factors,n_subsets=4,subsets_per_form=3,
    design="anchor",cfa_type="singlelevel",seed=15)
  stopifnot(!pooled$specification$anchor_fallback,
    identical(pooled$specification$anchors, single$specification$anchors),
    isTRUE(all.equal(pooled$loadings, single$loadings)))
  error <- tryCatch(pmd_forms(one,"id","time",factors=factors,
    n_subsets=4,subsets_per_form=3,design="anchor",cfa_type = "twolevel"), error=identity)
  stopifnot(inherits(error,"error"), grepl("multiple participants",conditionMessage(error)))

  # Fit data with intentionally opposite within- and between-level loading ranks.
  set.seed(518)
  opposed <- expand.grid(time=1:12,id=1:200)
  between <- rnorm(200)
  within <- rnorm(nrow(opposed))
  within_loading <- c(1.4,1.1,0.8,0.4)
  between_loading <- rev(within_loading)
  for (j in 1:4) opposed[[paste0("y",j)]] <- within_loading[j]*within +
    between_loading[j]*between[opposed$id] + rnorm(200,sd=0.4)[opposed$id] +
    rnorm(nrow(opposed),sd=0.65)
  chosen <- pmd_forms(opposed,"id","time",factors=list(Y=paste0("y",1:4)),
    n_subsets=4,subsets_per_form=3,design="anchor",cfa_type = "twolevel")
  fit <- lavaan::sem("level: 1\nW =~ y1 + y2 + y3 + y4\nlevel: 2\nB =~ y1 + y2 + y3 + y4",
    data=opposed,cluster="id",std.lv=TRUE,estimator="ML",missing="ml")
  pars <- lavaan::parameterEstimates(fit,standardized=TRUE)
  top <- function(f) {
    tab <- pars[pars$lhs == f & pars$op == "=~", ]
    tab$rhs[which.max(abs(tab$std.all))]
  }
  stopifnot(!chosen$specification$anchor_fallback, top("W") == "y1", top("B") == "y4",
    identical(chosen$specification$anchors, top("W")))
  cat("Single- and two-level CFA fits, within-level priority, and manual-anchor replay passed.\n")
}
