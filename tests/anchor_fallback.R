library(pmdplan)

if (requireNamespace("lavaan", quietly = TRUE)) local({
  # Constant indicators force actual fit failure; fallback anchors must be
  # reproducible, observed in every form, and replayable without another CFA.
  d <- expand.grid(time = 1:6, id = 1:8)
  factors <- list(Y = paste0("y", 1:5), X = paste0("x", 1:7))
  for (item in unlist(factors)) d[[item]] <- 1
  args <- list(data = d, id = "id", time = "time", factors = factors,
    n_subsets = 3, subsets_per_form = 2, design = "anchor", seed = 19)
  for (cfa_type in c("twolevel", "singlelevel")) {
    warnings <- character()
    set.seed(752)
    before <- .Random.seed
    invisible(capture.output(actual <- withCallingHandlers(
      do.call(pmd_forms, c(args, list(cfa_type = cfa_type))),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      })))
    expected <- do.call(pmd_forms, c(args, list(anchors = actual$specification$anchors)))
    invisible(capture.output(repeated <- suppressWarnings(do.call(pmd_forms,
      c(args, list(cfa_type = cfa_type))))))
    stopifnot(identical(before, .Random.seed),
      identical(actual$mask, repeated$mask), identical(actual$mask, expected$mask),
      identical(actual$specification$subsets, expected$specification$subsets),
      is.null(actual$loadings), actual$specification$anchor_fallback,
      actual$specification$loading_source == "fallback",
      actual$specification$cfa_type == cfa_type,
      nzchar(actual$specification$cfa_failure),
      sum(actual$specification$anchors %in% factors$Y) == 2L,
      sum(actual$specification$anchors %in% factors$X) == 3L,
      !any(actual$mask[, actual$specification$anchors]))
    fallback_warning <- warnings[grepl("Using the default rule", warnings, fixed = TRUE)]
    stopifnot(length(fallback_warning) == 1L,
      grepl("seed=19", fallback_warning, fixed = TRUE),
      grepl(actual$specification$cfa_failure, fallback_warning, fixed = TRUE))
    for (item in actual$specification$anchors)
      stopifnot(grepl(item, fallback_warning, fixed = TRUE))
  }
  # Invalid panels and nonnumeric CFA items remain input errors.
  bad_args <- args
  bad_args$data <- rbind(d, d[1, ])
  error <- tryCatch(do.call(pmd_forms, c(bad_args, list(cfa_type = "twolevel"))), error = identity)
  stopifnot(inherits(error, "error"), grepl("Duplicate id-time", conditionMessage(error)))
  bad_args$data <- d
  bad_args$data$y1 <- as.character(bad_args$data$y1)
  error <- tryCatch(do.call(pmd_forms, c(bad_args, list(cfa_type = "twolevel"))), error = identity)
  stopifnot(inherits(error, "error"), grepl("numeric continuous", conditionMessage(error)))
  cat("Actual CFA failure, unequal anchor counts, reproducible fallback and warning checks passed.\n")
})
