apply_pmd <- function(data, mask, id, time, items, design = "custom") {
  .validate_panel(data, id, time, items)
  if (!is.matrix(mask) || !is.logical(mask) || anyNA(mask) ||
      !identical(dim(mask), c(nrow(data), length(items))))
    .stop("mask must be a nonmissing logical matrix: rows of data x length(items).")
  if (!is.null(colnames(mask)) && !identical(colnames(mask), items))
    .stop("mask column names/order must match items exactly.")
  .strings(design, "design")
  if (length(design) != 1L) .stop("design must have length one.")
  colnames(mask) <- items
  original_missing <- do.call(cbind, lapply(data[items], is.na))
  if (.row_names_info(data) > 0L) rownames(original_missing) <- rownames(data)
  out <- data
  for (j in seq_along(items)) out[[items[j]]][mask[, j]] <- NA
  total <- mask | original_missing
  metadata <- data.frame(design = design,
    planned_missing_prop = mean(mask), original_missing_prop = mean(original_missing),
    total_missing_prop = mean(total), stringsAsFactors = FALSE)
  structure(list(data = out, mask = mask, original_missing = original_missing,
    metadata = metadata, id = id, time = time, items = items), class = "pmd_data")
}

print.pmd_data <- function(x, ...) {
  cat("Planned missing data: ", nrow(x$data), " rows, ", length(x$items),
      " item columns\n", sep = "")
  print(x$metadata, row.names = FALSE)
  invisible(x)
}

pmd_schedule <- function(x = NULL, N = NULL, TT = NULL, items = NULL,
                         pmd_items = items,
                         item_design = NULL, wave_design = NULL, seed = 1) {
  supplied <- names(match.call())[-1L]
  if (!is.null(x)) {
    extra <- setdiff(supplied, c("x", "items"))
    if (length(extra))
      .stop("When x is supplied, do not set ", paste(extra, collapse = ", "),
        ". Use pmd_schedule(x) or pmd_schedule(x, items = ...).")
    if (!inherits(x, "pmd_data")) .stop("x must be a pmd_data object.")
    if (is.null(items)) items <- x$items
    .strings(items, "items")
    if (anyDuplicated(items) || any(items %in% c("id", "time", x$id, x$time)))
      .stop("items must contain unique names other than id, time, and the input ID and time columns.")
    .columns(x$data, items)
    if (!all(x$items %in% items)) .stop("items must include all items in the existing PMD design.")
  } else {
    .scalar_number(N, "N", 1, .Machine$integer.max, TRUE)
    if (!is.numeric(TT) || !length(TT) || !(length(TT) %in% c(1L, N)) ||
        any(!is.finite(TT)) || any(TT < 1 | TT != floor(TT) | TT > .Machine$integer.max))
      .stop("TT must be a positive integer or a vector of N positive integers.")
    .strings(items, "items")
    if (anyDuplicated(items) || any(items %in% c("id", "time")))
      .stop("items must contain unique names other than id and time.")
    .strings(pmd_items, "pmd_items")
    if (anyDuplicated(pmd_items) || !all(pmd_items %in% items))
      .stop("pmd_items must contain unique names selected from items.")
    if (is.null(item_design) == is.null(wave_design))
      .stop("Supply exactly one of item_design or wave_design, with design inside that list.")
    .scalar_number(seed, "seed", 0, .Machine$integer.max, TRUE)
    occasions <- rep_len(TT, N)
    frame <- data.frame(id = rep(seq_len(N), occasions), time = sequence(occasions))
    for (item in items) frame[[item]] <- 0
    if (!is.null(item_design)) {
      settings <- .schedule_settings(item_design, "item_design",
        list(design = NULL, subsets = NULL, forms = NULL, subsets_per_form = NULL))
      if (is.null(settings$design)) .stop("Supply item_design$design: matrix or random.")
      design <- match.arg(settings$design, c("matrix", "random"))
      mask <- .schedule_item_mask(frame, pmd_items, settings, design, seed)
      x <- apply_pmd(frame, mask, "id", "time", pmd_items, design)
    } else {
      settings <- .schedule_settings(wave_design, "wave_design",
        list(design = NULL, first_prop = 0.5, interval = 1))
      if (is.null(settings$design)) .stop("Supply wave_design$design: balanced, consistent, or truncated.")
      design <- match.arg(settings$design, c("balanced", "consistent", "truncated"))
      if (design == "truncated") {
        if ("interval" %in% names(wave_design))
          .stop("wave_design$interval is only used with balanced or consistent designs.")
        x <- pmd_occasions(frame, "id", "time", pmd_items, design,
          first_prop = settings$first_prop, seed = seed)
      } else {
        x <- pmd_occasions(frame, "id", "time", pmd_items, design,
          first_prop = settings$first_prop, interval = settings$interval, seed = seed)
      }
    }
  }
  mask <- matrix(FALSE, nrow(x$data), length(items), dimnames = list(NULL, items))
  mask[, match(x$items, items)] <- x$mask
  out <- x$data[c(x$id, x$time)]
  names(out) <- c("id", "time")
  out[items] <- as.data.frame(!mask)
  rownames(out) <- NULL
  out
}

pmd_forms <- function(data, id, time, items = NULL,
                      design = c("matrix", "anchor", "random"),
                      subsets = NULL, forms = NULL, factors = NULL,
                      n_subsets = NULL, subsets_per_form = NULL,
                      anchors = NULL, cfa_type = NULL,
                      seed = 1) {
  design <- match.arg(design)
  .scalar_number(seed, "seed", 0, .Machine$integer.max, TRUE)
  if (!is.null(factors)) {
    .validate_factors(factors)
    factor_items <- unlist(factors, use.names = FALSE)
    if (is.null(items)) items <- factor_items
    else if (!setequal(items, factor_items)) .stop("items and factors must declare the same complete item set.")
  }
  if (is.null(items)) .stop("Declare all item columns using items or factors, including the anchor subset.")
  .validate_panel(data, id, time, items)
  if (design != "anchor" && (!is.null(anchors) || !is.null(cfa_type)))
    .stop("Anchor-selection arguments are only used with design='anchor'. Reuse the complete subsets for other designs.")
  if (!is.null(anchors)) {
    .strings(anchors, "anchors")
    if (anyDuplicated(anchors) || !all(anchors %in% items)) .stop("Invalid manual anchor items.")
  }
  if (design == "anchor" && is.null(anchors) && is.null(cfa_type))
    .stop("For design='anchor', supply anchors or cfa_type.")
  if (!is.null(anchors)) cfa_type <- NULL
  if (!is.null(cfa_type)) cfa_type <- match.arg(cfa_type, c("twolevel", "singlelevel"))
  loading_level <- if (is.null(cfa_type)) NULL else if (cfa_type == "twolevel") "within" else "single"
  anchor_name <- NULL
  generated_subsets <- is.null(subsets)
  generated_forms <- is.null(forms)
  selected_loadings <- NULL
  cfa_failure <- NULL
  if (generated_subsets) {
    if (is.null(factors) || is.null(n_subsets))
      .stop("Supply factors and n_subsets when subsets is omitted.")
    .validate_factors(factors)
    .scalar_number(n_subsets, "n_subsets", 2, length(items), TRUE)
    if (!is.null(cfa_type)) {
      anchor_counts <- ceiling(lengths(factors) / n_subsets)
      if (length(items) - sum(anchor_counts) < n_subsets - 1L)
        .stop("Too few non-anchor items to form the remaining subsets. Reduce n_subsets or supply anchors manually.")
      selected_loadings <- .cfa_loadings(data, id, time, factors, cfa_type)
      if (inherits(selected_loadings, "pmd_cfa_failure")) {
        cfa_failure <- selected_loadings$message
        selected_loadings <- NULL
        anchors <- .with_seed(seed, unlist(lapply(seq_along(factors), function(i) {
          its <- factors[[i]]
          its[sample.int(length(its), anchor_counts[i])]
        }), use.names = FALSE))
      } else {
        anchors <- unlist(lapply(seq_along(factors), function(i) {
          its <- factors[[i]]
          tab <- selected_loadings[selected_loadings$factor == names(factors)[i], , drop = FALSE]
          score <- abs(tab$loading[match(its, tab$item)])
          its[order(-score, seq_along(its))][seq_len(anchor_counts[i])]
        }), use.names = FALSE)
      }
    }
    subsets <- .partition_items(factors, n_subsets, anchors, seed)
  } else if (!is.null(cfa_type)) {
    .stop("CFA selection constructs new subsets. Omit subsets or reuse previously selected subsets with manual anchors.")
  }
  .validate_subsets(data, id, time, subsets, items)
  if (!is.null(n_subsets)) {
    .scalar_number(n_subsets, "n_subsets", 1, length(subsets), TRUE)
    if (n_subsets != length(subsets)) .stop("n_subsets must equal the length of subsets.")
  }
  n_subsets <- length(subsets)
  if (design == "anchor") {
    match_anchor <- which(vapply(subsets, setequal, logical(1), anchors))
    if (length(match_anchor) != 1L) .stop("anchors must exactly equal one complete subset.")
    anchor_name <- names(subsets)[match_anchor]
  } else anchors <- character()
  if (!generated_forms) {
    if (!is.list(forms) || !length(forms)) .stop("forms must be a nonempty list.")
    for (form in forms) {
      .strings(form, "Form subset names")
      if (anyDuplicated(form) || !all(form %in% names(subsets)))
        .stop("Each form must contain distinct existing subset names.")
      if (design == "anchor" && !anchor_name %in% form)
        .stop("Every anchor-design form must include the subset containing anchors.")
    }
    signatures <- vapply(forms, function(form)
      paste(sort(match(form, names(subsets))), collapse = ","), character(1))
    if (anyDuplicated(signatures)) .stop("Each form must specify a different subset combination.")
    subsets_per_form <- lengths(forms)
    log_n_forms <- log(length(forms))
  } else {
    if (is.null(subsets_per_form)) .stop("Supply subsets_per_form when forms is omitted.")
    .scalar_number(subsets_per_form, "subsets_per_form", 1, n_subsets, TRUE)
    candidates <- if (design == "anchor") setdiff(names(subsets), anchor_name) else names(subsets)
    n_select <- subsets_per_form - as.integer(design == "anchor")
    log_n_forms <- lchoose(length(candidates), n_select)
  }
  exhaustive_forms <- TRUE
  if (generated_forms && log_n_forms > log(10000)) {
    if (design != "random")
      .stop("More than 10000 forms would be generated. Supply forms with the subset combinations to use.")
    # Sample combinations directly, retaining only forms actually assigned.
    # Each candidate combination still has equal probability on every row.
    rows <- order(as.character(data[[id]]), data[[time]])
    selected <- .with_seed(seed, lapply(seq_len(nrow(data)), function(i)
      sort(sample.int(n_subsets, subsets_per_form))))
    signatures <- vapply(selected, paste, character(1), collapse = ",")
    unique_rows <- !duplicated(signatures)
    forms <- lapply(selected[unique_rows], function(ix) names(subsets)[ix])
    assignment <- integer(nrow(data))
    assignment[rows] <- match(signatures, signatures[unique_rows])
    exhaustive_forms <- FALSE
  } else {
    if (generated_forms) {
      forms <- if (n_select == 0L) list(character()) else
        utils::combn(candidates, n_select, simplify = FALSE)
      if (design == "anchor") forms <- lapply(forms, function(f) c(anchor_name, f))
    }
    assignment <- .assign_forms(data, id, time, length(forms), design, seed)
  }
  mask <- matrix(TRUE, nrow(data), length(items), dimnames = list(NULL, items))
  for (i in seq_along(forms)) {
    observed <- unique(unlist(subsets[forms[[i]]], use.names = FALSE))
    mask[assignment == i, observed] <- FALSE
  }
  out <- apply_pmd(data, mask, id, time, items, design)
  out$assignment <- as.integer(assignment)
  out$loadings <- selected_loadings
  out$specification <- list(design = design, items = items,
    subsets = subsets, forms = forms, exhaustive_forms = exhaustive_forms,
    n_candidate_forms = round(exp(log_n_forms)),
    anchors = anchors, factors = factors,
    n_subsets = n_subsets, subsets_per_form = subsets_per_form,
    generated_subsets = generated_subsets, generated_forms = generated_forms,
    cfa_type = cfa_type, loading_level = loading_level,
    anchor_fallback = !is.null(cfa_failure), cfa_failure = cfa_failure,
    seed = seed, loading_source = if (!is.null(cfa_failure)) "fallback" else
      if (is.null(cfa_type)) "manual" else
      "data")
  if (!is.null(cfa_failure))
    warning("CFA anchor selection failed: ", cfa_failure,
      " Using the default rule: randomly select anchor items within each factor",
      " (seed=", seed, ") and place them in subset ", anchor_name, ".",
      " Selected anchors: ", paste(anchors, collapse = ", "), ".", call. = FALSE)
  out
}

pmd_occasions <- function(data, id, time, pmd_item,
                          design = c("balanced", "consistent", "truncated"),
                          first_prop = 0.5, interval = 1, seed = 1) {
  .validate_panel(data, id, time, pmd_item)
  design <- match.arg(design)
  .scalar_number(first_prop, "first_prop", 0, 1)
  .scalar_number(seed, "seed", 0, .Machine$integer.max, TRUE)
  if (design == "truncated") {
    if (!missing(interval)) .stop("interval is only used with balanced or consistent designs.")
  } else {
    .scalar_number(interval, "interval", 0, .Machine$integer.max - 1, TRUE)
    period <- interval + 1L
  }
  subject_ids <- sort(unique(as.character(data[[id]])))
  units <- lapply(subject_ids, function(s) {
    rows <- which(as.character(data[[id]]) == s)
    rows[order(data[[time]][rows])]
  })
  n_subjects <- length(units)
  group <- rep(if (design == "truncated") NA_integer_ else 1L, n_subjects)
  if (design == "balanced") {
    # Allocate participants evenly; group sizes differ by at most one.
    phases <- seq_len(min(n_subjects, period))
    counts <- rep(n_subjects %/% period, length(phases))
    remainder <- seq_len(n_subjects %% period)
    counts[remainder] <- counts[remainder] + 1L
    group <- .with_seed(seed, rep(phases, counts)[sample.int(n_subjects)])
  }
  dropped <- rep(FALSE, nrow(data))
  summary_rows <- vector("list", n_subjects)
  for (j in seq_along(units)) {
    rows <- units[[j]]
    n <- length(rows)
    first_n <- floor(n * first_prop)
    second <- rows[seq_along(rows) > first_n]
    if (design == "truncated") {
      chosen <- second
    } else {
      # Group 1 measures positions period, 2*period, ... in Phase II.
      # Later groups shift this pattern by one occasion each.
      observed <- seq_along(second) %% period == group[j] - 1L
      chosen <- second[!observed]
    }
    dropped[chosen] <- TRUE
    summary_rows[[j]] <- data.frame(id = subject_ids[j], schedule_group = group[j],
      n_total = n, first_n = first_n, n_missing = length(chosen),
      n_observed = n - length(chosen), stringsAsFactors = FALSE)
  }
  mask <- matrix(dropped, nrow(data), length(pmd_item), dimnames = list(NULL, pmd_item))
  out <- apply_pmd(data, mask, id, time, pmd_item, design)
  out$subject_schedule <- do.call(rbind, summary_rows)
  out$specification <- list(design = design, first_prop = first_prop,
    interval = if (design == "truncated") NULL else interval, seed = seed)
  out
}
