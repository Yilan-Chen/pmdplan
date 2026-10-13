library(pmdplan)
local({
  d <- expand.grid(time = 1:5, id = 1:6)
  d$y1 <- as.numeric(seq_len(nrow(d))); d$y2 <- 1
  datasets <- list(d, d[-2, ], NULL)
  metadata <- data.frame(condition = "c", replication = 1:3)
  designs <- list(full = function(data, seed) apply_pmd(data,
    matrix(FALSE, nrow(data), 2), "id", "time", c("y1", "y2")),
    balanced = function(data, seed) pmd_occasions(data, "id", "time", c("y1", "y2"), seed = seed))
  set.seed(248); before <- .Random.seed
  x <- pmd_batch(datasets, designs, metadata, seed = 91)
  stopifnot(identical(before, .Random.seed), nrow(x$manifest) == 6,
    sum(x$manifest$status == "design_error") == 2, nrow(x$burden) == 4,
    identical(names(x$burden), c("condition", "replication", "design",
      "planned_missing_prop", "original_missing_prop", "total_missing_prop")),
    identical(x$data$r1_d1$data, d), identical(x$data$r2_d1$data, d[-2, ]))
  stopifnot(identical(x,
    pmd_batch(datasets, designs, metadata, seed = 91, mc.cores = 2)))
  directory <- tempfile("existing-pmd-")
  saved <- pmd_batch(datasets, designs, metadata, seed = 91, directory = directory)
  stopifnot(file.exists(file.path(directory, "manifest.csv")),
    !file.exists(file.path(directory, "pmd_batch.rds")),
    sum(grepl("[.]rds$", list.files(directory))) == 4,
    identical(readRDS(saved$manifest$file[1])$data, d))
  for (i in seq_len(nrow(saved$manifest))) {
    row <- saved$manifest[i, ]
    if (row$status == "ok") stopifnot(identical(readRDS(row$file), saved$data[[row$object]]))
    else stopifnot(is.na(row$file), is.null(saved$data[[row$object]]))
  }
  disk_manifest <- utils::read.csv(file.path(directory, "manifest.csv"), stringsAsFactors = FALSE)
  stopifnot(identical(disk_manifest$object, saved$manifest$object),
    identical(disk_manifest$status, saved$manifest$status))
  err <- tryCatch(pmd_batch(datasets, designs, metadata, directory = directory), error = identity)
  stopifnot(inherits(err, "error"))
  unlink(directory, recursive = TRUE)
  # Failed folder creation must emit its warning and then fail clearly.
  collision <- tempfile(); file.create(collision)
  warnings <- character()
  err <- tryCatch(withCallingHandlers(pmdplan:::.ensure_directory(file.path(collision, "child")),
    warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") }), error = identity)
  stopifnot(inherits(err, "error"), length(warnings) > 0)
  unlink(collision)
  cat("Existing-data PMD batches, output manifests, failed-replication retention and visible directory warnings passed.\n")
})
