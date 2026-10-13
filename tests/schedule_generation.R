library(pmdplan)
local({
  items <- paste0("y", 1:4)
  frame <- expand.grid(time = 1:8, id = 1:6)
  for (item in items) frame[[item]] <- 0
  observed <- function(schedule) as.matrix(schedule[setdiff(names(schedule), c("id", "time"))])
  expect_error <- function(expr, pattern) {
    error <- tryCatch({force(expr); NULL}, error = identity)
    stopifnot(inherits(error, "error"), grepl(pattern, conditionMessage(error), fixed = TRUE))
  }
  set.seed(184)
  rng_before <- .Random.seed
  balanced <- pmd_schedule(N = 6, TT = 8, items = items, wave_design = list(design = "balanced"), seed = 42)
  stopifnot(identical(.Random.seed, rng_before),
    identical(names(balanced), c("id", "time", items)), nrow(balanced) == 48,
    all(observed(balanced)[balanced$time <= 4, ]), sum(observed(balanced)) == 144,
    identical(balanced, pmd_schedule(pmd_occasions(frame, "id", "time", items, seed = 42))))
  consistent <- pmd_schedule(N = 6, TT = 8, items = items, wave_design = list(design = "consistent", first_prop = .5, interval = 1))
  stopifnot(identical(consistent$y1, consistent$time %in% c(1:4, 6, 8)))
  shortened <- pmd_schedule(N = 6, TT = 8, items = items, wave_design = list(design = "truncated", first_prop = .75))
  stopifnot(identical(shortened$y1, shortened$time <= 6))
  for (proportion in c(0, .1, .5, .75, 1)) {
    truncated <- pmd_schedule(N = 3, TT = c(5, 8, 11), items = c(items, "daily"),
      pmd_items = items, wave_design = list(design = "truncated", first_prop = proportion))
    cutoffs <- floor(c(5, 8, 11) * proportion)
    stopifnot(identical(truncated$y1, truncated$time <= cutoffs[truncated$id]),
      all(truncated$daily), all(rowSums(observed(truncated)[, items, drop = FALSE]) %in% c(0, 4)))
  }
  # Equal phase allocation works with remainders and fewer participants than phases.
  for (participants in c(1, 2, 7, 13)) for (spacing in c(0, 1, 2, 4)) {
    period <- spacing + 1
    phases <- pmd_schedule(N = participants, TT = period, items = "y1", wave_design = list(design = "balanced", first_prop = 0, interval = spacing))
    phase_counts <- tabulate(phases$time[phases$y1], nbins = period)
    stopifnot(diff(range(phase_counts)) <= 1, sum(phase_counts) == participants,
      all(tapply(phases$y1, phases$id, sum) == 1))
  }

  # User-defined subsets replace singleton and factor-based defaults.
  subsets <- list(A = c("y1", "y2"), B = c("y3", "y4"))
  paired <- pmd_schedule(N = 6, TT = 8, items = items,
    item_design = list(design = "matrix", subsets = subsets, subsets_per_form = 1))
  custom <- pmd_schedule(N = 6, TT = 8, items = items,
    item_design = list(design = "matrix", subsets = subsets, forms = list("A", "B")))
  stopifnot(identical(paired, custom), identical(paired$y1, paired$y2),
    identical(paired$y3, paired$y4), all(rowSums(observed(paired)) == 2),
    identical(paired, pmd_schedule(pmd_forms(frame, "id", "time", items = items,
      subsets = subsets, forms = list("A", "B")))))

  # Incomplete form families are accepted and used exactly as supplied.
  singleton <- list(A = "y1", B = "y2", C = "y3", D = "y4")
  for (design in c("matrix", "random")) {
    restricted <- pmd_schedule(N = 6, TT = 8, items = items,
      item_design = list(design = design, subsets = singleton, forms = list(c("A", "B"), c("A", "C"))))
    stopifnot(all(restricted$y1), !any(restricted$y4),
      all(rowSums(observed(restricted)) == 2), all(xor(restricted$y2, restricted$y3)))
  }

  # Custom forms determine their own size; subsets_per_form does not override them.
  for (design in c("matrix", "random")) {
    settings <- list(subsets = singleton, forms = list("A", c("B", "C", "D")))
    flexible <- pmd_schedule(N = 6, TT = 8, items = items, item_design = c(list(design = design), settings))
    stopifnot(all(rowSums(observed(flexible)) %in% c(1, 3)),
      identical(flexible$y2, flexible$y3), identical(flexible$y3, flexible$y4),
      all(xor(flexible$y1, flexible$y2)))
    settings$subsets_per_form <- 2
    stopifnot(identical(flexible, pmd_schedule(N = 6, TT = 8, items = items, item_design = c(list(design = design), settings))))
  }

  # Shared anchor items appear once in the output and are always measured.
  shared <- list(A = c("anchor", "y1"), B = c("anchor", "y2"), C = c("anchor", "y3"))
  for (design in c("matrix", "random")) {
    for (settings in list(list(subsets = shared, subsets_per_form = 2),
                         list(subsets = shared, forms = list(c("A", "B"), c("B", "C"))))) {
      anchor <- pmd_schedule(N = 7, TT = 9, items = c("anchor", "y1", "y2", "y3", "daily"),
        pmd_items = c("anchor", "y1", "y2", "y3"), item_design = c(list(design = design), settings), seed = 15)
      stopifnot(all(anchor$anchor), all(anchor$daily), all(rowSums(observed(anchor)) == 4),
        !anyDuplicated(names(anchor)), !anyNA(anchor), identical(.Random.seed, rng_before))
    }
  }

  # Arbitrary numbers of forms and participants need not be integer multiples.
  rotation <- pmd_schedule(N = 13, TT = 12, items = items,
    item_design = list(design = "matrix", subsets = singleton, subsets_per_form = 2), seed = 17)
  patterns <- apply(observed(rotation), 1, paste0, collapse = "")
  for (subject in unique(rotation$id)) {
    ix <- which(rotation$id == subject)
    stopifnot(length(unique(patterns[ix[1:6]])) == 6,
      identical(patterns[ix[1:6]], patterns[ix[7:12]]))
  }
  stopifnot(diff(range(table(patterns[rotation$time == 1]))) == 1)
  random <- pmd_schedule(N = 6, TT = 8, items = items,
    item_design = list(design = "random", subsets = singleton, subsets_per_form = 2), seed = 17)
  stopifnot(all(rowSums(observed(random)) == 2), identical(.Random.seed, rng_before),
    identical(random, pmd_schedule(N = 6, TT = 8, items = items,
      item_design = list(design = "random", subsets = singleton, subsets_per_form = 2), seed = 17)))

  # Large random form spaces do not need exhaustive enumeration.
  many_items <- paste0("q", 1:20)
  many <- stats::setNames(as.list(many_items), many_items)
  large <- pmd_schedule(N = 3, TT = 4, items = many_items,
    item_design = list(design = "random", subsets = many, subsets_per_form = 10))
  stopifnot(all(rowSums(observed(large)) == 10))

  # The automatic matrix limit concerns combinations, not participants or rows.
  expect_error(pmd_schedule(N = 1, TT = 1, items = many_items,
    item_design = list(design = "matrix", subsets = many, subsets_per_form = 10)), "10000 forms")
  chosen_forms <- list(many_items[1:10], many_items[11:20])
  restricted_large <- pmd_schedule(N = 3, TT = 4, items = many_items,
    item_design = list(design = "matrix", subsets = many, forms = chosen_forms))
  stopifnot(all(rowSums(observed(restricted_large)) == 10))

  # All five designs affect only selected items, preserving requested column order.
  all_items <- c("always_before", "y4", "y1", "always_middle", "y2", "y3")
  for (design in c("matrix", "random", "balanced", "consistent", "truncated")) {
    extra <- if (design %in% c("matrix", "random"))
      list(item_design = list(design = design, subsets = singleton, subsets_per_form = 3)) else
        list(wave_design = list(design = design))
    full <- do.call(pmd_schedule, c(list(N = 6, TT = 8, items = all_items,
      pmd_items = items, seed = 29), extra))
    selected <- do.call(pmd_schedule, c(list(N = 6, TT = 8, items = items,
      seed = 29), extra))
    stopifnot(nrow(full) == 48, identical(names(full), c("id", "time", all_items)),
      all(full$always_before), all(full$always_middle), identical(full[items], selected[items]))
    unequal <- do.call(pmd_schedule, c(list(N = 3, TT = c(5, 8, 10), items = items,
      seed = 29), extra))
    stopifnot(identical(as.integer(table(unequal$id)), c(5L, 8L, 10L)),
      identical(as.numeric(tapply(unequal$time, unequal$id, max)), c(5, 8, 10)), !anyNA(unequal))
  }
  sparse <- pmd_schedule(N = 6, TT = 12, items = c(items, "daily"), pmd_items = items, wave_design = list(design = "balanced", first_prop = .25, interval = 2))
  stopifnot(all(sparse$daily), all(observed(sparse)[sparse$time <= 3, ]),
    all(tapply(rowSums(observed(sparse)), sparse$id, sum) == 36))

  # Existing masks retain row order and ignore pre-existing missing responses.
  panel <- data.frame(person = rep(c("B", "A"), each = 3),
    occasion = c(2, 8, 15, 1, 4, 20), score = NA_real_, daily = NA_real_)
  mask <- matrix(c(FALSE, TRUE, FALSE, TRUE, FALSE, TRUE), ncol = 1)
  old <- apply_pmd(panel, mask, "person", "occasion", "score")
  extracted <- pmd_schedule(old)
  stopifnot(identical(extracted$id, panel$person), identical(extracted$time, panel$occasion),
    identical(names(extracted), c("id", "time", "score")), identical(extracted$score, !mask[, 1]),
    all(old$original_missing))
  expanded <- pmd_schedule(old, items = c("daily", "score"))
  stopifnot(all(expanded$daily), identical(expanded$score, extracted$score))
  odd_names <- pmd_schedule(N = 1, TT = 2, items = c("item one", "\u9898\u76ee"), wave_design = list(design = "consistent", interval = 0))
  stopifnot(identical(names(odd_names), c("id", "time", "item one", "\u9898\u76ee")), all(observed(odd_names)))

  expect_error(pmd_schedule(N = 3, TT = c(5, 8), items = items), "TT must")
  expect_error(pmd_schedule(N = 3, TT = 8, items = c("id", "y1")), "unique names")
  expect_error(pmd_schedule(N = 3, TT = 8, items = items), "Supply exactly one")
  expect_error(pmd_schedule(N = 3, TT = 8, items = items, item_design = list(design = "matrix")), "item_design$subsets must")
  expect_error(pmd_schedule(N = 3, TT = 8, items = items, wave_design = list()), "Supply wave_design$design")
  expect_error(pmd_schedule(N = 3, TT = 8, items = items,
    item_design = list(design = "matrix", subsets_per_form = 2)), "item_design$subsets must")
  expect_error(pmd_schedule(N = 3, TT = 8, items = items,
    item_design = list(design = "matrix", subsets = subsets)), "Supply item_design$subsets_per_form")
  expect_error(pmd_schedule(N = 3, TT = 8, items = items,
    wave_design = list(design = "consistent", group_prop = .5)), "Unknown wave_design entries: group_prop")
  expect_error(pmd_schedule(N = 3, TT = 8, items = items, pmd_items = "absent"), "selected from items")
  expect_error(pmd_schedule(N = 3, TT = 8, items = items, pmd_items = c("y1", "y1")), "unique names")
  expect_error(pmd_schedule(N = 3, TT = 8, items = items,
    item_design = list(design = "matrix", subsets = subsets, subsets_per_form = 1), wave_design = list()), "Supply exactly one")
  expect_error(pmd_schedule(N = 3, TT = 8, items = items,
    wave_design = list(), item_design = list(design = "balanced")), "Supply exactly one")
  expect_error(pmd_schedule(N = 3, TT = 8, items = items,
    wave_design = list(design = "balanced", intervl = 1)), "Unknown wave_design entries: intervl")
  expect_error(pmd_schedule(N = 3, TT = 8, items = items,
    item_design = list(design = "matrix", subsets = subsets, n_observed = 1)), "Unknown item_design entries: n_observed")
  expect_error(pmd_schedule(N = 3, TT = 8, items = items,
    item_design = list(design = "matrix", subsets = list(A = c(items, "extra")), subsets_per_form = 1)), "cover exactly pmd_items")
  expect_error(pmd_schedule(N = 3, TT = 8, items = items,
    item_design = list(design = "matrix", subsets = singleton, forms = list(c("A", "B"), c("B", "A")))), "different subset combination")
  expect_error(pmd_schedule(N = 3, TT = 8, items = items,
    wave_design = list(design = "truncated", interval = 2)), "wave_design$interval is only used")
  expect_error(pmd_schedule(N = 3, TT = 8, items = items,
    wave_design = list(design = "truncated", missing_prop = .5)), "Unknown wave_design entries: missing_prop")

  # Design is required inside the selected family; families cannot be mixed.
  expect_error(pmd_schedule(N = 3, TT = 8, items = items,
    item_design = list(subsets = subsets)), "Supply item_design$design")
  expect_error(pmd_schedule(N = 3, TT = 8, items = items,
    item_design = list(design = "balanced", subsets = subsets)), "arg")
  expect_error(pmd_schedule(N = 3, TT = 8, items = items,
    wave_design = list(design = "matrix")), "arg")
  expect_error(pmd_schedule(N = 3, TT = 8, items = items, item_design = "matrix"), "named list")
  expect_error(pmd_schedule(N = 3, TT = 8, items = items, wave_design = "balanced"), "named list")
  stopifnot(!"design" %in% names(formals(pmd_schedule)))

  expect_error(pmd_schedule(old, N = 3), "When x is supplied")
  expect_error(pmd_schedule(old, items = "daily"), "include all items")
  expect_error(pmd_schedule(old, pmd_items = "score"), "When x is supplied")
  expect_error(pmd_schedule(N = 1, TT = 2, items = items, item_design = list(design = "anchor")), "arg")
  cat("Wide schedules, explicit settings, shared anchors, rotations, random forms and wave designs passed.\n")
})
