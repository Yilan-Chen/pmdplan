library(pmdplan)
assert_error <- function(code, pattern = NULL) {
  error <- tryCatch({ force(code); NULL }, error = identity)
  stopifnot(inherits(error, "error"))
  if (!is.null(pattern)) stopifnot(grepl(pattern, conditionMessage(error), fixed = TRUE))
}
make_panel <- function(k, n = 7, times = 1:12) {
  d <- expand.grid(time = times, id = seq_len(n))
  for (v in paste0("y", seq_len(k))) d[[v]] <- seq_len(nrow(d))
  d
}
form_signature <- function(forms) sort(vapply(forms, function(f) paste(sort(f), collapse = ","), character(1)))

# All supported K/m combinations: exact form family, burden, balance and rotation.
for (k in 2:8) for (m in seq_len(k)) for (design in c("anchor", "matrix", "random")) {
  n_forms <- if (design == "anchor") choose(k - 1, m - 1) else choose(k, m)
  d <- make_panel(k, times = seq_len(2 * n_forms + 1))
  items <- paste0("y", seq_len(k))
  subsets <- stats::setNames(as.list(items), LETTERS[seq_len(k)])
  set.seed(902); old_seed <- .Random.seed
  z <- pmd_forms(d, "id", "time", subsets = subsets, items = items,
    subsets_per_form = m, design = design, anchors = if (design == "anchor") "y1" else NULL, seed = 217)
  stopifnot(identical(old_seed, .Random.seed), identical(z$specification$subsets, subsets),
    identical(z$data$id, d$id), identical(z$data$time, d$time),
    all(rowSums(!z$mask) == m), abs(mean(z$mask) - (1 - m/k)) < 1e-12,
    z$specification$n_subsets == k, z$specification$subsets_per_form == m,
    length(z$specification$forms) == n_forms)
  expected <- utils::combn(names(subsets), m, simplify = FALSE)
  if (design == "anchor") expected <- Filter(function(f) "A" %in% f, expected)
  stopifnot(identical(form_signature(z$specification$forms), form_signature(expected)))
  for (fi in seq_along(z$specification$forms)) {
    observed <- unlist(subsets[z$specification$forms[[fi]]], use.names = FALSE)
    stopifnot(all(!z$mask[z$assignment == fi, observed, drop = FALSE]))
  }
  if (design == "anchor") stopifnot(!any(z$mask[, "y1"]))
  if (design != "random") {
    for (tt in unique(d$time)) {
      counts <- tabulate(z$assignment[d$time == tt], nbins = n_forms)
      stopifnot(max(counts) - min(counts) <= 1)
    }
    for (ii in unique(d$id)) {
      a <- z$assignment[d$id == ii]
      for (start in seq_len(length(a) - n_forms + 1))
        stopifnot(length(unique(a[seq.int(start, length.out = n_forms)])) == n_forms)
      if (n_forms > 1) stopifnot(all(diff(a) != 0))
    }
  }
}
# A is part of every candidate universe. Equal-probability random allocation
# deliberately has neither count balancing nor forced within-person rotation.
d <- make_panel(4, n = 60, times = 1:20)
items <- paste0("y", 1:4); subsets <- stats::setNames(as.list(items), LETTERS[1:4])
r <- pmd_forms(d, "id", "time", subsets=subsets, items=items,
  subsets_per_form=1, design="random", seed=14)
stopifnot(all(abs(tabulate(r$assignment, nbins=4)/nrow(d) - 0.25) < 0.06),
  any(vapply(split(r$assignment,d$id), function(a) any(diff(a)==0), logical(1))))
for (design in c("anchor", "matrix", "random")) {
  a <- pmd_forms(d, "id", "time", subsets=subsets, items=items,
    subsets_per_form=2, design=design, anchors=if (design == "anchor") "y1" else NULL)
  b <- pmd_forms(d, "id", "time", subsets=subsets, items=items,
    forms=a$specification$forms, design=design, anchors=if (design == "anchor") "y1" else NULL)
  stopifnot(identical(a$mask,b$mask), identical(a$assignment,b$assignment))
  order_rows <- sample.int(nrow(d))
  shuffled <- pmd_forms(d[order_rows,], "id", "time", subsets=subsets,
    items=items, subsets_per_form=2, design=design, anchors=if (design == "anchor") "y1" else NULL)
  stopifnot(identical(unname(a$mask),unname(shuffled$mask[order(order_rows),])),
    identical(a$assignment,shuffled$assignment[order(order_rows)]))
}
# Incomplete declarations and obsolete interfaces fail rather than excluding A.
assert_error(pmd_forms(d,"id","time",subsets=subsets[-1],items=items,subsets_per_form=1), "cover exactly")
assert_error(pmd_forms(d,"id","time",subsets=subsets,subsets_per_form=1), "Declare all")
assert_error(pmd_forms(d,"id","time",groups=subsets,subsets_per_form=1))
assert_error(pmd_forms(d,"id","time",subsets=subsets,items=items,subsets_per_form=0))
assert_error(pmd_forms(d,"id","time",subsets=subsets,items=items,subsets_per_form=5))
selected_forms <- pmd_forms(d,"id","time",subsets=subsets,items=items,forms=list("B","C","D"))
stopifnot(all(selected_forms$mask[, "y1"]), length(selected_forms$specification$forms) == 3)
assert_error(pmd_forms(d,"id","time",subsets=subsets,items=items,
  forms=list("A","A","C","D")), "different subset combination")
incomplete_forms <- pmd_forms(d[-1,],"id","time",subsets=subsets,items=items,subsets_per_form=2)
stopifnot(nrow(incomplete_forms$data) == nrow(d) - 1L)
assert_error(pmdplan:::.validate_panel(rbind(d,d[1,]),"id","time",items))

# Custom unequal subsets and a non-first anchor, including K > 26.
u <- list(A="y1", B=c("y2","y3"), C="y4")
a <- pmd_forms(d,"id","time",subsets=u,items=items,
  subsets_per_form=1,design="anchor",anchors=c("y2","y3"))
stopifnot(all(!a$mask[,c("y2","y3")]), all(a$mask[,c("y1","y4")]))
for (k in c(3,5,6,27)) {
  big <- make_panel(2*k, n=3, times=1:5)
  fac <- list(Y=paste0("y",seq_len(2*k)))
  auto <- pmd_forms(big,"id","time",factors=fac,n_subsets=k,
    subsets_per_form=k,design="matrix")
  stopifnot(length(auto$specification$subsets)==k, !any(auto$mask))
}
# A large random form space is sampled directly without enumerating all forms.
big <- make_panel(20, n=3, times=1:4)
large <- pmd_forms(big,"id","time",factors=list(Y=paste0("y",1:20)),
  n_subsets=20,subsets_per_form=10,design="random")
stopifnot(!large$specification$exhaustive_forms, large$specification$n_candidate_forms==choose(20,10),
  all(rowSums(!large$mask)==10), length(large$assignment)==nrow(big))

# Existing and planned missingness may overlap; other columns are excluded.
dn <- d; dn$y1[1] <- NA_real_; dn$y2[3] <- NA_real_
dn$unselected <- NA_character_
mask <- matrix(FALSE,nrow(d),length(items),dimnames=list(NULL,items))
mask[1:2,"y1"] <- TRUE
z <- apply_pmd(dn,mask,"id","time",items)
schedule <- pmd_schedule(z)
stopifnot(identical(names(z$metadata), c("design", "planned_missing_prop",
    "original_missing_prop", "total_missing_prop")),
  z$metadata$planned_missing_prop==2/length(mask),
  z$metadata$original_missing_prop==2/length(mask),
  z$metadata$total_missing_prop==3/length(mask),
  identical(z$original_missing, is.na(as.matrix(dn[items]))),
  identical(z$data$unselected, dn$unselected),
  sum(!as.matrix(schedule[items]))==2,
  identical(names(schedule), c("id", "time", items)),
  identical(schedule, pmd_schedule(apply_pmd(d, mask, "id", "time", items))))
baseline <- apply_pmd(dn, mask & FALSE, "id", "time", items)
stopifnot(identical(baseline$data, dn),
  baseline$metadata$planned_missing_prop==0,
  baseline$metadata$total_missing_prop==baseline$metadata$original_missing_prop,
  !any(c("validate_panel", ".validate_panel") %in% getNamespaceExports("pmdplan")),
  is.function(getFromNamespace(".validate_panel", "pmdplan")))

# Phase-one floor rule, variable intervals, consistency and direct truncation.
panel <- make_panel(1,n=12,times=1:15)
for (interval in 0:3) for (first_prop in c(0,0.3,0.5,1)) {
  b <- pmd_occasions(panel,"id","time","y1",first_prop=first_prop,interval=interval)
  first_n <- floor(15*first_prop)
  stopifnot(all(!b$mask[panel$time<=first_n,,drop=FALSE]))
  for (tt in unique(panel$time[panel$time>first_n]))
    stopifnot(sum(!b$mask[panel$time==tt,])==12/(interval+1))
  i <- pmd_occasions(panel,"id","time","y1",first_prop=first_prop,interval=interval,design = "consistent")
  tr <- pmd_occasions(panel,"id","time","y1",design = "truncated",first_prop=first_prop)
  stopifnot(all(tr$subject_schedule$n_observed == first_n),
    identical(as.vector(tr$mask), panel$time > first_n))
  expected_missing <- panel$time > first_n & (panel$time-first_n) %% (interval+1) != 0
  stopifnot(identical(as.vector(i$mask),expected_missing))
}
i <- pmd_occasions(panel,"id","time","y1",first_prop=0.3,design = "consistent")
stopifnot(setequal(panel$time[panel$id==1&i$mask[,1]], seq(5,15,2)))
b <- pmd_occasions(panel,"id","time","y1",interval=2)
stopifnot(all(table(b$subject_schedule$schedule_group) == 4L))
uneven <- make_panel(1,n=7,times=c(1,3,8,10,12,19))
b <- pmd_occasions(uneven,"id","time","y1",interval=2)
stopifnot(identical(b$data$time,uneven$time),diff(range(table(b$subject_schedule$schedule_group)))==1)
incomplete <- pmd_occasions(panel[-1,],"id","time","y1")
stopifnot(nrow(incomplete$data) == nrow(panel) - 1L)
assert_error(pmd_occasions(panel,"id","time","y1",design = "random"))
assert_error(pmd_occasions(panel,"id","time","y1",interval=1.5))
assert_error(pmd_occasions(panel,"id","time","y1",interval=2,group_prop=c(0.5,0.5)))
assert_error(pmd_occasions(panel,"id","time","y1",missing_prop=0.5))
assert_error(pmd_occasions(panel,"id","time","y1",design="truncated",interval=1))

# Isolate ranking from CFA estimation using a controlled internal result.
ranked_forms <- pmd_forms
environment(ranked_forms) <- list2env(list(.cfa_loadings = function(data, id, time, factors, cfa_type)
  pmdplan:::.validate_loadings(load, factors, if (cfa_type == "twolevel") "within" else "single")), parent = environment(pmd_forms))
# Select one of four, or two of eight, from each factor.
for (ni in c(4L,8L)) {
  dat <- make_panel(ni,n=7,times=1:12)
  fac <- list(Y=paste0("y",seq_len(ni)),X=paste0("x",seq_len(ni)))
  for(v in fac$X) dat[[v]] <- seq_len(nrow(dat))
  load <- do.call(rbind,lapply(names(fac),function(f) data.frame(factor=f,item=fac[[f]],
    level="within",loading=seq(0.1,0.9,length.out=ni))))
  a <- ranked_forms(dat,"id","time",factors=fac,n_subsets=4,subsets_per_form=3,
    design="anchor",cfa_type = "twolevel",seed=3)
  expected <- unlist(lapply(fac,function(v) tail(v,ni/4)),use.names=FALSE)
  stopifnot(setequal(a$specification$anchors,expected),!any(a$mask[,expected]),
    all(lengths(a$specification$subsets)==ni/2),a$metadata$planned_missing_prop==0.25)
  for(f in names(fac)) for(s in a$specification$subsets) stopifnot(sum(s%in%fac[[f]])==ni/4)
  manual <- pmd_forms(dat,"id","time",factors=fac,n_subsets=4,subsets_per_form=3,
    design="anchor",anchors=expected,seed=3)
  stopifnot(identical(a$mask,manual$mask))
  # Reusing the complete CFA-selected subsets keeps A in matrix/random sampling.
  for(design in c("matrix","random")) {
    reuse <- pmd_forms(dat,"id","time",subsets=a$specification$subsets,
      factors=fac,subsets_per_form=3,design=design, anchors=if (design == "anchor") "y1" else NULL)
    stopifnot(identical(reuse$specification$subsets,a$specification$subsets),
      setequal(reuse$items,unlist(fac)),mean(reuse$mask)==0.25,
      any(reuse$mask[,expected]))
  }
}
load$loading <- 0.8
level2 <- load; level2$level <- "between"; level2$loading <- seq_len(nrow(level2))/100
load <- rbind(load,level2)
a <- ranked_forms(dat,"id","time",factors=fac,n_subsets=4,subsets_per_form=1,
  design="anchor",cfa_type = "twolevel")
stopifnot(setequal(a$specification$anchors,c("y1","y2","x1","x2")))
# Conflicting ranks: the within level favors the first items and between favors the last.
load$loading[load$level == "within"] <- rep(seq(0.9, 0.2, length.out = ni), 2)
within <- ranked_forms(dat,"id","time",factors=fac,n_subsets=4,subsets_per_form=1,
  design="anchor",cfa_type = "twolevel")
explicit <- ranked_forms(dat,"id","time",factors=fac,n_subsets=4,subsets_per_form=1,
  design="anchor",cfa_type="twolevel")
stopifnot(setequal(within$specification$anchors,c("y1","y2","x1","x2")),
  identical(within$mask, explicit$mask), within$specification$cfa_type == "twolevel",
  within$specification$loading_level == "within", all(within$loadings$level == "within"))
saved_load <- load
load <- load[load$level == "within", ]
load$level <- "single"
single <- ranked_forms(dat,"id","time",factors=fac,n_subsets=4,subsets_per_form=1,
  design="anchor",cfa_type="singlelevel")
stopifnot(identical(single$mask, within$mask), single$specification$cfa_type == "singlelevel",
  single$specification$loading_level == "single", all(single$loadings$level == "single"))
load <- saved_load
load$loading[1] <- -1
absolute <- ranked_forms(dat,"id","time",factors=fac,n_subsets=4,subsets_per_form=1,
  design="anchor",cfa_type = "twolevel")
stopifnot("y1" %in% absolute$specification$anchors)
load$loading[1] <- NA_real_
assert_error(ranked_forms(dat,"id","time",factors=fac,n_subsets=4,subsets_per_form=1,
  design="anchor",cfa_type = "twolevel"))
assert_error(pmdplan:::.need("pmdplan_nonexistent_dependency_123"), "Please install")

# Combined PSR, error-list and iteration checks.
normal <- list(tech8 = list(psr = data.frame(iteration = c(100, 200),
  psr = c(1.2, 1.05))), errors = list())
stopifnot(mplus_convergence(normal, n_factors = 2)$converged)
abnormal <- normal
abnormal$errors <- list("THE MODEL ESTIMATION DID NOT TERMINATE NORMALLY", "other")
stopifnot(mplus_convergence(abnormal, n_factors = 2)$errors_flag,
          !mplus_convergence(abnormal, n_factors = 2)$converged)
abnormal$errors <- abnormal$errors[1]
stopifnot(!mplus_convergence(abnormal, n_factors = 2)$errors_flag,
          mplus_convergence(abnormal, n_factors = 2)$converged)
normal$tech8$psr$psr <- c(1.01, NA_real_)
stopifnot(!mplus_convergence(normal, n_factors = 2)$converged)
normal$tech8$psr$psr <- c(1.01, 1.1)
stopifnot(!mplus_convergence(normal, n_factors = 2)$converged)
normal$tech8$psr <- NULL
stopifnot(!mplus_convergence(normal, n_factors = 2)$converged)
normal$tech8$psr <- data.frame(iteration = c(100, 200), psr = c(1.2, 1.03))
stopifnot(mplus_convergence(normal, n_factors = 2)$last_psr == 1.03)

# Hand-calculated performance, including a missing/failed third replication.
est <- data.frame(condition = "c", design = "a", replication = 1:2, parameter = "theta",
  estimate = c(1, 3), sd = c(1, 1), lower = c(0, 2.5), upper = c(2, 4))
runs <- data.frame(condition = "c", design = "a", replication = 1:3,
  status = c("ok", "ok", "fit_error"), converged = c(TRUE, TRUE, FALSE))
population_value <- data.frame(condition = "c", parameter = "theta", value = 2)
e <- pmdplan:::.evaluate_estimates(est, population_value, runs)
stopifnot(e$n_attempted == 3, e$n_valid == 2, e$bias == 0, e$rmse == 1,
          e$coverage == 0.5, e$convergence_rate == 2/3,
          e$mean_estimate == 2, e$mean_sd == 1,
          isTRUE(all.equal(e$empirical_sd, sqrt(2))))
population_value$value <- 0
stopifnot(is.na(pmdplan:::.evaluate_estimates(est, population_value, runs)$relative_bias))
population_value$value <- 2
assert_error(pmdplan:::.evaluate_estimates(rbind(est, est[1, ]), population_value, runs))
assert_error(pmdplan:::.evaluate_estimates(est, population_value, runs[1, , drop = FALSE]))
screen <- screen_designs(e, "theta")
stopifnot(!screen$eligible)
stopifnot(!screen_designs(e, c("theta", "absent"))$eligible)

cat("pmdplan core regression tests passed.\n")
