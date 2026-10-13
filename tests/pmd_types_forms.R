library(pmdplan)
local({
  d <- expand.grid(time = 1:4, id = c("p2", "p1", "p3", "p4"), stringsAsFactors = FALSE)
  d$text <- rep(c("yes", "no", NA_character_, "yes"), 4)
  d$category <- factor(rep(c("low", "high", "low", NA_character_), 4))
  d$flag <- rep(c(TRUE, FALSE, NA, TRUE), 4)
  d$score <- seq_len(nrow(d))
  d$other <- "unchanged"
  rownames(d) <- paste0("row", seq_len(nrow(d)))
  items <- c("text", "category", "flag", "score")
  subsets <- stats::setNames(as.list(items), LETTERS[1:4])
  forms <- list("A", c("B", "C", "D"))
  base <- pmd_forms(d, "id", "time", subsets = subsets, items = items, forms = forms)
  stopifnot(identical(base$specification$subsets_per_form, c(1L, 3L)),
    all(rowSums(!base$mask) %in% c(1, 3)),
    identical(base$original_missing, is.na(as.matrix(d[items]))),
    identical(base$data[c("id", "time", "other")], d[c("id", "time", "other")]))
  for (item in items) {
    stopifnot(identical(class(base$data[[item]]), class(d[[item]])),
      all(is.na(base$data[[item]][base$mask[, item]])),
      identical(base$data[[item]][!base$mask[, item]], d[[item]][!base$mask[, item]]))
  }
  stopifnot(identical(levels(base$data$category), levels(d$category)))
  mask <- matrix(rep(c(TRUE, FALSE), length.out = nrow(d) * length(items)), nrow(d),
    dimnames = list(NULL, items))
  applied <- apply_pmd(d, mask, "id", "time", items)
  stopifnot(identical(applied$original_missing, base$original_missing))
  numeric_occasions <- pmd_occasions(d, "id", "time", items, first_prop = .25)
  times <- list(
    as.Date("2026-01-01") + d$time,
    as.POSIXct("2026-01-01", tz = "UTC") + d$time * 3600,
    sprintf("visit%02d", d$time),
    factor(paste0("T", c(1, 2, 10, 11))[d$time], levels = paste0("T", c(1, 2, 10, 11)), ordered = TRUE)
  )
  for (time_values in times) {
    dd <- d
    dd$time <- time_values
    shuffled <- rev(seq_len(nrow(dd)))
    x <- pmd_forms(dd[shuffled, ], "id", "time", subsets = subsets,
      items = items, forms = forms)
    stopifnot(identical(x$assignment[order(shuffled)], base$assignment),
      identical(x$data$time, time_values[shuffled]),
      identical(x$data$other, dd$other[shuffled]))
    wave <- pmd_occasions(dd, "id", "time", items, first_prop = .25)
    stopifnot(identical(wave$mask, numeric_occasions$mask), identical(wave$data$time, time_values),
      identical(pmd_schedule(x)$time, x$data$time))
  }
  # Shared items and incomplete form families have the same meaning as in schedules.
  shared <- list(A = c("text", "category"), B = c("text", "flag"), C = c("text", "score"))
  for (design in c("matrix", "random")) {
    x <- pmd_forms(d, "id", "time", subsets = shared, items = items,
      forms = list("A", c("B", "C")), design = design)
    stopifnot(!any(x$mask[, "text"]), identical(x$data$text, d$text),
      all(rowSums(!x$mask) %in% c(2, 3)))
  }
  anchor <- pmd_forms(d, "id", "time", subsets = subsets, items = items,
    forms = list("A", c("A", "C", "D")), design = "anchor", anchors = "text")
  stopifnot(!any(anchor$mask[, "text"]), all(rowSums(!anchor$mask) %in% c(1, 3)))
  stopifnot(!any(c("n_observed", "loadings", "loading_rank", "cfa_data", "loading_level", "mode", "anchor_method", "anchor_subset") %in% names(formals(pmd_forms))))
  # Automatic generated subsets still divide every factor equally.
  auto <- pmd_forms(d, "id", "time", factors = list(F1 = c("text", "category"),
    F2 = c("flag", "score")), n_subsets = 2, subsets_per_form = 1)
  stopifnot(all(lengths(auto$specification$subsets) == 2), all(rowSums(!auto$mask) == 2))
  stopifnot(auto$specification$generated_subsets, auto$specification$generated_forms,
    !base$specification$generated_subsets, !base$specification$generated_forms,
    is.null(auto$specification$cfa_type), is.null(auto$loadings))
  # Supplied forms can refer to generated subsets without a mode switch.
  fac <- list(F1 = c("text", "category"), F2 = c("flag", "score"))
  supplied <- pmd_forms(d, "id", "time", factors = fac, n_subsets = 2,
    forms = list("A", c("A", "B")))
  replay <- pmd_forms(d, "id", "time", items = items,
    subsets = supplied$specification$subsets, forms = list("A", c("A", "B")))
  stopifnot(supplied$specification$generated_subsets, !supplied$specification$generated_forms,
    identical(supplied$mask, replay$mask), all(rowSums(!supplied$mask) %in% c(2, 4)))
  # NULL preserves the no-CFA path, including user-selected anchors.
  manual <- pmd_forms(d, "id", "time", factors = fac, n_subsets = 2,
    subsets_per_form = 1, design = "anchor", anchors = c("text", "flag"))
  explicit_null <- pmd_forms(d, "id", "time", factors = fac, n_subsets = 2,
    subsets_per_form = 1, design = "anchor", anchors = c("text", "flag"), cfa_type = NULL)
  stopifnot(identical(manual$mask, explicit_null$mask), is.null(manual$loadings),
    !any(manual$mask[, c("text", "flag")]))
  expect_error <- function(expr, pattern) {
    e <- tryCatch({force(expr); NULL}, error = identity)
    stopifnot(inherits(e, "error"), grepl(pattern, conditionMessage(e), fixed = TRUE))
  }
  expect_error(pmd_forms(d, "id", "time", items = items), "Supply factors and n_subsets")
  expect_error(pmd_forms(d, "id", "time", items = items, subsets = subsets), "Supply subsets_per_form")
  override <- pmd_forms(d, "id", "time", factors = fac, n_subsets = 2,
    subsets_per_form = 1, design = "anchor", anchors = c("text", "flag"), cfa_type = "twolevel")
  stopifnot(identical(override$mask, manual$mask), is.null(override$loadings),
    is.null(override$specification$cfa_type))
  expect_error(pmd_forms(d, "id", "time", factors = fac, n_subsets = 2,
    subsets_per_form = 1, design = "anchor"), "supply anchors or cfa_type")
  expect_error(pmd_forms(d, "id", "time", items = items, subsets = subsets,
    forms = forms, design = "anchor", cfa_type = "twolevel"), "CFA selection constructs new subsets")
  expect_error(pmd_forms(d, "id", "time", items = items, subsets = subsets,
    forms = forms, cfa_type = "singlelevel"), "only used with design='anchor'")
  # ID column classes and date-time classes are retained by every PMD path.
  for (ids in list(as.numeric(sub("p", "", d$id)), d$id, factor(d$id))) {
    dd <- d
    dd$id <- ids
    dd$time <- as.POSIXct("2026-01-01", tz = "UTC") + d$time * 3600
    outputs <- list(
      pmd_forms(dd, "id", "time", items = items, subsets = subsets, forms = forms),
      pmd_occasions(dd, "id", "time", items),
      apply_pmd(dd, mask, "id", "time", items))
    for (result in outputs) {
      schedule <- pmd_schedule(result)
      stopifnot(identical(result$data$id, ids), identical(schedule$id, ids),
        identical(result$data$time, dd$time), identical(schedule$time, dd$time))
    }
  }
  cat("Mixed item types, preserved classes, time formats, shared anchors and variable form sizes passed.\n")
})
