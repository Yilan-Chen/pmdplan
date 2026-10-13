library(pmdplan)
data("affect", package = "pmdplan")
items <- c(paste0("x", 1:4), paste0("y", 1:4))
subsets <- list(A = c("x1", "y1"), B = c("x2", "y2"),
                C = c("x3", "y3"), D = c("x4", "y4"))
designs <- list(
  matrix = function(data, seed) {
    pmd_forms(data, "N_index", "time", items = items,
      design = "matrix", subsets = subsets, subsets_per_form = 3, seed = seed)
  },
  balanced = function(data, seed) {
    pmd_occasions(data, "N_index", "time", pmd_item = items,
      design = "balanced", first_prop = 0.5, interval = 1, seed = seed)
  }
)
# One empirical dataset; for simulations, supply one list entry per replication.
batch <- pmd_batch(list(affect), designs, include_complete = TRUE)
batch$manifest
head(batch$data[[1]]$data)
