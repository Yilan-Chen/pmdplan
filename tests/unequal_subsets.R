library(pmdplan)
local({
  factors <- list(Y = paste0("y", 1:5), X = paste0("x", 1:7))
  items <- unlist(factors, use.names = FALSE)
  d <- expand.grid(time = 1:9, id = 1:7)
  for (nm in items) d[[nm]] <- seq_len(nrow(d))
  # Each item is allocated once, including when K exceeds a factor's count.
  for (k in 2:length(items)) for (design in c("matrix", "random")) {
    set.seed(59)
    before <- .Random.seed
    result <- pmd_forms(d, "id", "time", factors = factors, n_subsets = k,
      subsets_per_form = 1, design = design, seed = 21)
    subsets <- result$specification$subsets
    allocated <- unlist(subsets, use.names = FALSE)
    stopifnot(identical(before, .Random.seed), setequal(allocated, items),
      !anyDuplicated(allocated), all(lengths(subsets) > 0L),
      diff(range(lengths(subsets))) <= 1L)
    for (its in factors) {
      counts <- vapply(subsets, function(s) sum(s %in% its), integer(1))
      stopifnot(diff(range(counts)) <= 1L)
    }
  }
  # A five-item factor split three ways must produce 2, 2, and 1 items.
  result <- pmd_forms(d, "id", "time", factors = factors[1], n_subsets = 3,
    subsets_per_form = 1)
  stopifnot(identical(sort(lengths(result$specification$subsets)), c(C = 1L, A = 2L, B = 2L)))

  # Manual anchors can have arbitrary counts and always bypass CFA, including
  # nonsensical CFA settings. A test double would fail if CFA were called.
  manual_forms <- pmd_forms
  environment(manual_forms) <- list2env(list(.cfa_loadings = function(...)
    stop("CFA must not be called")), parent = environment(pmd_forms))
  anchors <- c("y1", "y2", "y3", "x1")
  manual <- manual_forms(d, "id", "time", factors = factors, n_subsets = 3,
    subsets_per_form = 2, design = "anchor", anchors = anchors,
    cfa_type = "ignored setting")
  stopifnot(!any(manual$mask[, anchors]), identical(manual$specification$anchors, anchors),
    is.null(manual$loadings), is.null(manual$specification$cfa_type),
    !"anchor_subset" %in% names(formals(pmd_forms)))
  for (its in factors) {
    counts <- vapply(manual$specification$subsets[-1], function(s) sum(s %in% its), integer(1))
    stopifnot(diff(range(counts)) <= 1L)
  }
  replay <- manual_forms(d, "id", "time", items = items,
    subsets = manual$specification$subsets, subsets_per_form = 2,
    design = "anchor", anchors = anchors, cfa_type = "twolevel")
  stopifnot(identical(replay$mask, manual$mask))

  # Check the default CFA anchor counts and highest-loading selection directly.
  ranked <- pmd_forms
  environment(ranked) <- list2env(list(.cfa_loadings = function(data, id, time, factors, cfa_type) {
    do.call(rbind, lapply(names(factors), function(f)
      data.frame(factor = f, item = factors[[f]], level = "within", loading = seq_along(factors[[f]]))))
  }), parent = environment(pmd_forms))
  cfa <- ranked(d, "id", "time", factors = factors, n_subsets = 3,
    subsets_per_form = 2, design = "anchor", cfa_type = "twolevel")
  stopifnot(setequal(cfa$specification$anchors, c("y4", "y5", "x5", "x6", "x7")),
    !any(cfa$mask[, cfa$specification$anchors]))
  bad <- tryCatch(pmd_forms(d, "id", "time", factors = factors, n_subsets = 12,
    subsets_per_form = 1, design = "anchor", anchors = anchors), error = identity)
  stopifnot(inherits(bad, "error"), grepl("Too few non-anchor items", conditionMessage(bad)))
})
