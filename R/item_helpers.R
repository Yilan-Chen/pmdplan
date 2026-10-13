.validate_factors <- function(factors) {
  if (!is.list(factors) || !length(factors) || is.null(names(factors)))
    .stop("factors must be a named nonempty list of character vectors.")
  .strings(names(factors), "Factor identifiers")
  if (anyDuplicated(names(factors))) .stop("Factor identifiers must be unique.")
  for (f in factors) .strings(f, "Factor items")
  if (anyDuplicated(unlist(factors, use.names = FALSE)))
    .stop("An item cannot belong to more than one factor in automatic subset construction.")
  invisible(TRUE)
}

.partition_items <- function(factors, n_subsets, anchors, seed) {
  subset_names <- if (n_subsets <= 26L) LETTERS[seq_len(n_subsets)] else paste0("S", seq_len(n_subsets))
  g <- stats::setNames(rep(list(character()), n_subsets), subset_names)
  destinations <- seq_len(n_subsets)
  if (!is.null(anchors)) {
    if (sum(lengths(factors)) - length(anchors) < n_subsets - 1L)
      .stop("Too few non-anchor items to form the remaining subsets. Reduce n_subsets or select fewer anchors.")
    g[[1L]] <- anchors
    destinations <- destinations[-1L]
  }
  .with_seed(seed, {
    for (its in factors) {
      remaining <- setdiff(its, anchors)
      if (!length(remaining)) next
      remaining <- remaining[sample.int(length(remaining))]
      counts <- rep(length(remaining) %/% length(destinations), length(destinations))
      extra <- order(lengths(g[destinations]), seq_along(destinations))[
        seq_len(length(remaining) %% length(destinations))]
      counts[extra] <- counts[extra] + 1L
      groups <- rep(seq_along(destinations), counts)
      for (j in seq_along(destinations))
        g[[destinations[j]]] <- c(g[[destinations[j]]], remaining[groups == j])
    }
    g
  })
}

.validate_loadings <- function(loadings, factors, level) {
  .columns(loadings, c("factor", "item", "level", "loading"))
  tab <- loadings
  for (v in c("factor", "item", "level")) tab[[v]] <- as.character(tab[[v]])
  if (anyNA(tab$level) || any(!tab$level %in% c("within", "between", "single")))
    .stop("Loading levels must be within, between, or single.")
  tab <- tab[tab$level == level, c("factor", "item", "level", "loading"), drop = FALSE]
  if (!nrow(tab) || !is.numeric(tab$loading) || any(!is.finite(tab$loading)))
    .stop("Selected standardized loadings must be finite numeric values.")
  .unique_key(tab, c("factor", "item"))
  expected <- do.call(rbind, lapply(names(factors), function(f)
    data.frame(factor = f, item = factors[[f]], stringsAsFactors = FALSE)))
  ix <- match(.key(expected, c("factor", "item")), .key(tab, c("factor", "item")))
  if (anyNA(ix)) .stop("A standardized loading is required for every factor-item pair.")
  tab[ix, , drop = FALSE]
}

.cfa_loadings <- function(data, id, time, factors, cfa_type) {
  .need("lavaan")
  .validate_factors(factors)
  items <- unlist(factors, use.names = FALSE)
  .validate_panel(data, id, time, items)
  if (!all(vapply(data[items], function(x) is.numeric(x) && !is.complex(x) &&
      !is.factor(x) && !any(is.infinite(x)), logical(1))))
    .stop("CFA anchor selection requires numeric continuous items; otherwise select anchors manually.")
  if (any(lengths(factors) < 3L))
    .stop("The built-in CFA needs at least three items per factor; otherwise select anchors manually.")
  if (any(!grepl("^[A-Za-z][A-Za-z0-9_]*$", c(id, items))))
    .stop("Automatic CFA requires syntactically simple column identifiers.")
  twolevel <- cfa_type == "twolevel"
  if (twolevel && (length(unique(data[[id]])) < 2L || !any(table(data[[id]]) > 1L)))
    .stop("Two-level CFA requires multiple participants and repeated observations.")
  nf <- length(factors)
  f_names <- paste0(if (twolevel) "pmdW" else "pmdF", seq_len(nf))
  b_names <- if (twolevel) paste0("pmdB", seq_len(nf)) else character()
  if (any(c(f_names, b_names) %in% names(data))) .stop("Reserved CFA factor identifiers collide with data columns.")
  syntax <- vapply(seq_len(nf), function(i)
    paste(f_names[i], "=~", paste(factors[[i]], collapse = " + ")), character(1))
  if (twolevel) syntax <- c("level: 1", syntax, "level: 2", vapply(seq_len(nf), function(i)
    paste(b_names[i], "=~", paste(factors[[i]], collapse = " + ")), character(1)))
  syntax <- paste(syntax, collapse = "\n")
  # These loadings guide item selection; this model is not a DSEM estimator.
  # Only fitting/extraction failures trigger fallback. Invalid user inputs and
  # unavailable dependencies above remain explicit errors.
  tryCatch({
    fit <- lavaan::sem(model = syntax, data = data, cluster = if (twolevel) id else NULL,
                       std.lv = TRUE, estimator = "ML", missing = "ml")
    if (!isTRUE(lavaan::lavInspect(fit, "converged")) ||
        !isTRUE(lavaan::lavInspect(fit, "post.check")))
      .stop(if (twolevel) "Two-level" else "Single-level",
        " CFA failed to converge or returned an inadmissible solution.")
    pars <- lavaan::parameterEstimates(fit, standardized = TRUE)
    .columns(pars, c("lhs", "op", "rhs", "std.all"))
    # Anchor ranking always uses the within-level loadings for two-level CFA.
    level <- if (twolevel) "within" else "single"
    keep <- pars$op == "=~" & pars$lhs %in% f_names
    tab <- data.frame(factor = names(factors)[match(pars$lhs[keep], f_names)],
      item = pars$rhs[keep], level = level, loading = pars$std.all[keep], stringsAsFactors = FALSE)
    .validate_loadings(tab, factors, level)
  }, error = function(e)
    structure(list(message = conditionMessage(e)), class = "pmd_cfa_failure"))
}

.subject_positions <- function(data, id, time) {
  subject_index <- match(as.character(data[[id]]), sort(unique(as.character(data[[id]]))))
  counts <- tabulate(subject_index)
  # Each participant's supplied rows define positions 1, 2, ... after sorting by time.
  # .validate_panel has already ruled out duplicate participant-time pairs.
  rows <- order(subject_index, data[[time]])
  position <- integer(nrow(data))
  position[rows] <- sequence(counts)
  list(subject = subject_index, position = position, n_subjects = length(counts))
}

.assign_forms <- function(data, id, time, n_forms, design, seed) {
  if (design == "random") {
    # Canonical row order makes the allocation independent of input row sorting.
    rows <- order(as.character(data[[id]]), data[[time]])
    a <- integer(nrow(data))
    a[rows] <- .with_seed(seed, sample.int(n_forms, nrow(data), replace = TRUE))
    return(a)
  }
  panel <- .subject_positions(data, id, time)
  .with_seed(seed, {
    # Balance participants across starting phases, then rotate by each participant's own
    # position. Shorter records end without changing anyone else's sequence.
    form_order <- sample.int(n_forms)
    offsets <- rep(seq_len(n_forms) - 1L, length.out = panel$n_subjects)
    offsets <- offsets[sample.int(panel$n_subjects)]
    index <- (offsets[panel$subject] + panel$position - 1L) %% n_forms + 1L
    as.integer(form_order[index])
  })
}

.schedule_item_mask <- function(data, items, settings, design, seed) {
  subsets <- settings$subsets
  forms <- settings$forms
  subsets_per_form <- settings$subsets_per_form
  if (!is.list(subsets) || !length(subsets) || is.null(names(subsets)))
    .stop("item_design$subsets must be a named list of item vectors.")
  .strings(names(subsets), "Subset names")
  if (anyDuplicated(names(subsets))) .stop("Subset names must be unique.")
  for (subset in subsets) {
    .strings(subset, "Items in each subset")
    if (anyDuplicated(subset)) .stop("Item names must be unique within each subset.")
  }
  if (!setequal(unlist(subsets, use.names = FALSE), items))
    .stop("item_design$subsets must cover exactly pmd_items; items may appear in more than one subset.")
  if (is.null(forms)) {
    if (is.null(subsets_per_form))
      .stop("Supply item_design$subsets_per_form when forms is omitted.")
    .scalar_number(subsets_per_form, "item_design$subsets_per_form", 1, length(subsets), TRUE)
    if (design == "random") {
      # Draw uniformly from all combinations without enumerating a large form space.
      selected <- .with_seed(seed, lapply(seq_len(nrow(data)), function(i)
        sample.int(length(subsets), subsets_per_form)))
      rows <- order(as.character(data$id), data$time)
      mask <- matrix(TRUE, nrow(data), length(items), dimnames = list(NULL, items))
      for (i in seq_along(rows))
        mask[rows[i], unique(unlist(subsets[selected[[i]]], use.names = FALSE))] <- FALSE
      return(mask)
    }
    if (lchoose(length(subsets), subsets_per_form) > log(10000))
      .stop("More than 10000 forms would be generated. Supply item_design$forms to select the combinations to rotate.")
    forms <- utils::combn(names(subsets), subsets_per_form, simplify = FALSE)
  } else {
    if (!is.list(forms) || !length(forms))
      .stop("item_design$forms must be a list of subset-name vectors.")
    for (form in forms) {
      .strings(form, "Subset names in each form")
      if (anyDuplicated(form) || !all(form %in% names(subsets)))
        .stop("Each form must contain unique names drawn from item_design$subsets.")
    }
    signatures <- vapply(forms, function(form)
      paste(sort(match(form, names(subsets))), collapse = ","), character(1))
    if (anyDuplicated(signatures)) .stop("Each form must specify a different subset combination.")
  }
  assignment <- .assign_forms(data, "id", "time", length(forms), design, seed)
  mask <- matrix(TRUE, nrow(data), length(items), dimnames = list(NULL, items))
  for (i in seq_along(forms)) {
    observed <- unique(unlist(subsets[forms[[i]]], use.names = FALSE))
    mask[assignment == i, observed] <- FALSE
  }
  mask
}
