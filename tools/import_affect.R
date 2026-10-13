# Rebuild the package dataset from the prepared baseline DAT supplied by the user.
# Usage: Rscript tools/import_affect.R /path/to/data1.dat /path/to/pmdplan
# The DAT must contain N_index, x1-x4, y1-y4 and time, in that order.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Supply the baseline DAT path and package directory.")
source_file <- normalizePath(args[1], mustWork = TRUE)
package_dir <- normalizePath(args[2], mustWork = TRUE)
affect <- utils::read.table(
  source_file, header = FALSE, na.strings = "-9",
  col.names = c("N_index", paste0("x", 1:4), paste0("y", 1:4), "time")
)
items <- c(paste0("x", 1:4), paste0("y", 1:4))
stopifnot(
  identical(dim(affect), c(9500L, 10L)),
  length(unique(affect$N_index)) == 125L,
  !anyNA(affect),
  all(vapply(split(affect$time, affect$N_index),
             function(x) identical(x, seq_len(76)), logical(1))),
  all(as.matrix(affect[items]) >= 0),
  all(as.matrix(affect[items]) <= 100)
)
data_dir <- file.path(package_dir, "data")
if (!dir.exists(data_dir)) dir.create(data_dir, showWarnings = TRUE)
if (!dir.exists(data_dir)) stop("Could not create the package data directory.")
save(affect, file = file.path(data_dir, "affect.rda"),
     compress = "xz", version = 2)
cat("Saved affect: 9500 rows, 125 participants, 76 occasions each.\n")
cat("Source DAT MD5:", unname(tools::md5sum(source_file)), "\n")
