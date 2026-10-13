library(pmdplan)

local({
  items <- paste0("y", 1:4)
  subsets <- stats::setNames(as.list(items), LETTERS[1:4])
  make_data <- function(lengths) {
    d <- do.call(rbind, lapply(seq_along(lengths), function(i)
      data.frame(id = sprintf("s%03d", i), time = i * 1000 + seq_len(lengths[i])^2,
        position = seq_len(lengths[i]))))
    for (item in items) d[[item]] <- 1
    d
  }
  allocate <- function(d, design = "anchor", m = 3, forms = NULL) {
    pmd_forms(d, "id", "time", subsets = subsets, items = items,
      subsets_per_form = m, design = design, anchors = if (design == "anchor") "y2" else NULL,
      forms = forms, seed = 21)
  }

  # The user's 60-person example: 123, 124, 234 are precisely the three
  # allowable forms when item/subset 2 (B) is the compulsory anchor.
  d <- make_data(rep(6, 60))
  d$y1[1] <- NA_real_
  set.seed(975)
  before <- .Random.seed
  x <- allocate(d)
  stopifnot(identical(before, .Random.seed), identical(x$data$id, d$id),
    identical(x$data$time, d$time), identical(x$data$position, d$position),
    identical(x$original_missing, is.na(as.matrix(d[items]))),
    all(!x$mask[, "y2"]), all(rowSums(!x$mask) == 3L))
  signatures <- vapply(x$specification$forms, function(f)
    paste(sort(match(f, LETTERS[1:4])), collapse = ""), character(1))
  stopifnot(setequal(signatures, c("123", "124", "234")))
  for (p in 1:6)
    stopifnot(identical(tabulate(x$assignment[d$position == p], nbins = 3), rep(20L, 3)))
  sequences <- matrix(x$assignment, nrow = 60, byrow = TRUE)
  schemes <- apply(sequences[, 1:3], 1, paste, collapse = ",")
  stopifnot(length(unique(schemes)) == 3L, all(table(schemes) == 20L),
    identical(sequences[, 1:3], sequences[, 4:6]))
  for (i in 1:60) for (start in 1:4)
    stopifnot(setequal(sequences[i, start:(start + 2)], 1:3))
  custom <- allocate(d, forms = x$specification$forms)
  stopifnot(identical(custom$assignment, x$assignment), identical(custom$mask, x$mask))

  # Unequal T, including a one-row subject, works for every K=4 observation
  # count and both rotational designs. A subject's sequence depends on their
  # ordinal positions, not the time labels or another person's record length.
  lengths <- c(1, 2, 3, 5, 7, 8, 11)
  u <- make_data(lengths)
  canonical <- u
  canonical$time <- canonical$position
  full <- make_data(rep(max(lengths), length(lengths)))
  for (design in c("anchor", "matrix")) for (m in 1:4) {
    a <- allocate(u, design, m)
    b <- allocate(canonical, design, m)
    f <- allocate(full, design, m)
    retained <- full$position <= rep(lengths, each = max(lengths))
    stopifnot(identical(a$assignment, b$assignment),
      identical(a$assignment, f$assignment[retained]),
      identical(unname(a$mask), unname(f$mask[retained, , drop = FALSE])),
      all(rowSums(!a$mask) == m), identical(a$data$time, u$time))
    n_forms <- length(a$specification$forms)
    counts <- tabulate(a$assignment[u$position == 1], nbins = n_forms)
    stopifnot(diff(range(counts)) <= 1L)
    for (id in unique(u$id)) {
      sequence <- a$assignment[u$id == id]
      if (length(sequence) >= n_forms) for (start in seq_len(length(sequence) - n_forms + 1))
        stopifnot(setequal(sequence[seq.int(start, length.out = n_forms)], seq_len(n_forms)))
    }
    order_rows <- sample.int(nrow(u))
    shuffled <- allocate(u[order_rows, ], design, m)
    stopifnot(identical(a$assignment, shuffled$assignment[order(order_rows)]),
      identical(unname(a$mask), unname(shuffled$mask[order(order_rows), , drop = FALSE])))
  }

  # A removed middle row is not an implicit skipped form: the next supplied
  # row takes the next form. NA responses on existing rows still take a turn.
  gap <- d[-2, ]
  ordinal <- gap
  ordinal$time <- ave(ordinal$time, ordinal$id, FUN = seq_along)
  a <- allocate(gap)
  b <- allocate(ordinal)
  stopifnot(identical(a$assignment, b$assignment), identical(a$mask, b$mask))
  no_na <- d
  no_na$y1[1] <- 1
  stopifnot(identical(x$assignment, allocate(no_na)$assignment))

  # Groups differ by at most one if N is indivisible by F or smaller than F.
  for (n in c(1, 2, 5, 61)) {
    small <- make_data(rep(4, n))
    a <- allocate(small)
    for (p in 1:4)
      stopifnot(diff(range(tabulate(a$assignment[small$position == p], nbins = 3))) <= 1L)
  }
  cat("Person-based form rotation: 60-person schemes, unequal T, irregular times and reproducibility passed.\n")
})
