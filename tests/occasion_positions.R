library(pmdplan)

local({
  # Every subject has a different time grid, including unequal gaps. Half miss
  # odd stage-two positions and half miss even positions when interval = 1.
  d <- do.call(rbind, lapply(1:6, function(i)
    data.frame(id = paste0("s", i), time = i * 10 + c(0, 1, 3, 7, 8, 15), y = 1, z = 2)))
  d$y[1] <- NA_real_
  set.seed(680)
  before <- .Random.seed
  b <- pmd_occasions(d, "id", "time", c("y", "z"), interval = 1, seed = 41)
  stopifnot(identical(before, .Random.seed),
    identical(b$data$id, d$id), identical(b$data$time, d$time),
    identical(b$original_missing, is.na(as.matrix(d[c("y", "z")]))),
    all(table(b$subject_schedule$schedule_group) == 3L))
  schedules <- matrix(b$mask[, "y"], nrow = 6, byrow = TRUE)
  stopifnot(all(!schedules[, 1:3]), all(colSums(schedules[, 4:6]) == 3L))
  for (i in 1:6) {
    group <- b$subject_schedule$schedule_group[i]
    expected <- if (group == 1L) c(TRUE, FALSE, TRUE) else c(FALSE, TRUE, FALSE)
    stopifnot(identical(unname(schedules[i, 4:6]), expected))
  }
  consistent <- pmd_occasions(d, "id", "time", c("y", "z"), design = "consistent")
  stopifnot(identical(unname(consistent$mask[, "y"]),
    rep(c(FALSE, FALSE, FALSE, TRUE, FALSE, TRUE), 6)))

  # Per-person stage boundaries, zero/full first stages, short records, and
  # all supported interval examples on unequal numbers of rows.
  lengths <- c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13)
  u <- do.call(rbind, lapply(seq_along(lengths), function(i)
    data.frame(id = sprintf("s%02d", i), time = i * 100 + seq_len(lengths[i])^2, y = 1)))
  for (interval in 0:3) for (first_prop in c(0, 0.3, 0.5, 1)) {
    x <- pmd_occasions(u, "id", "time", "y", interval = interval, first_prop = first_prop)
    stopifnot(all(table(x$subject_schedule$schedule_group) == 12 / (interval + 1)),
      identical(x$subject_schedule$n_total, as.integer(lengths)),
      all(x$subject_schedule$first_n == floor(lengths * first_prop)))
    for (i in seq_along(lengths)) {
      rows <- which(u$id == x$subject_schedule$id[i])
      first_n <- floor(lengths[i] * first_prop)
      observed <- rep(FALSE, lengths[i])
      observed[seq_len(first_n)] <- TRUE
      # Build the expected observation positions as arithmetic sequences.
      first_observed <- x$subject_schedule$schedule_group[i] - 1L
      if (first_observed == 0L) first_observed <- interval + 1L
      start <- first_n + first_observed
      if (start <= lengths[i]) observed[seq.int(start, lengths[i], by = interval + 1L)] <- TRUE
      stopifnot(identical(unname(x$mask[rows, "y"]), !observed),
        x$subject_schedule$n_missing[i] == sum(!observed))
    }
    same <- pmd_occasions(u, "id", "time", "y", interval = interval,
      first_prop = first_prop, design = "consistent")
    truncated <- pmd_occasions(u, "id", "time", "y", design = "truncated",
      first_prop = first_prop)
    stopifnot(all(truncated$subject_schedule$n_observed == floor(lengths * first_prop)),
      all(same$subject_schedule$n_observed >= truncated$subject_schedule$n_observed))
    for (i in seq_along(lengths)) {
      rows <- which(u$id == truncated$subject_schedule$id[i])
      stopifnot(identical(unname(truncated$mask[rows, "y"]),
        seq_along(rows) > floor(lengths[i] * first_prop)))
    }
  }
  # Allocation follows sorted times, independent of input row order.
  order_rows <- sample.int(nrow(u))
  x <- pmd_occasions(u, "id", "time", "y", interval = 2)
  shuffled <- pmd_occasions(u[order_rows, ], "id", "time", "y", interval = 2)
  stopifnot(identical(unname(x$mask), unname(shuffled$mask[order(order_rows), , drop = FALSE])),
    identical(x$subject_schedule, shuffled$subject_schedule),
    all(table(x$subject_schedule$schedule_group) == 4L))
  odd <- pmd_occasions(d[d$id != "s6", ], "id", "time", "y")
  stopifnot(identical(as.integer(table(odd$subject_schedule$schedule_group)), c(3L, 2L)))
  # Fewer participants than phase patterns still gives balanced allocation.
  small <- pmd_occasions(d[d$id == "s1", ], "id", "time", "y", interval = 3)
  stopifnot(identical(small$mask[, "y"], c(FALSE, FALSE, FALSE, TRUE, TRUE, TRUE)),
    small$metadata$design == "balanced", consistent$metadata$design == "consistent")

  # Equal measurement counts can be specified explicitly for design comparisons.
  complete <- expand.grid(time = 1:76, id = 1:7)
  complete$y <- 1
  complete$other <- "unchanged"
  consistent <- pmd_occasions(complete, "id", "time", pmd_item = "y",
    design = "consistent", first_prop = .5, interval = 1)
  truncated <- pmd_occasions(complete, "id", "time", pmd_item = "y",
    design = "truncated", first_prop = .75)
  stopifnot(all(consistent$subject_schedule$n_observed == 57L),
    all(truncated$subject_schedule$n_observed == 57L),
    identical(truncated$data$other, complete$other),
    truncated$metadata$design == "truncated", is.null(truncated$specification$interval),
    identical(pmd_occasions(complete, "id", "time", "y", design = "truncate")$mask,
      pmd_occasions(complete, "id", "time", "y", design = "truncated")$mask))
  # Both interfaces must produce exactly the same measurement arrangements.
  frame <- data.frame(id = rep(1:13, 1:13), time = sequence(1:13), y = 1, other = 1)
  for (design in c("balanced", "consistent", "truncated")) {
    settings <- list(design = design, first_prop = .3)
    if (design != "truncated") settings$interval <- 3
    masked <- do.call(pmd_occasions, c(list(data = frame, id = "id", time = "time", pmd_item = "y"), settings))
    scheduled <- pmd_schedule(N = 13, TT = 1:13, items = c("y", "other"),
      pmd_items = "y", wave_design = settings)
    stopifnot(identical(pmd_schedule(masked, items = c("y", "other")), scheduled))
  }
  cat("Subject-specific occasion grids, balanced/consistent phases and unequal lengths passed.\n")
})
