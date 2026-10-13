library(pmdplan)
data("affect", package = "pmdplan")
items <- list(Sy = paste0("y", 1:4), Sx = paste0("x", 1:4),
              Ty = paste0("y", 1:4), Tx = paste0("x", 1:4))
folder <- tempfile("mplus-analysis-")
# Prepare input files without running Mplus.
prepared <- analyze_mplus(affect, items = items,
  id = "N_index", time = "time", processors = 2, biterations = "(1000)",
  path = folder, run = FALSE)
prepared$manifest
unlink(folder, recursive = TRUE)
