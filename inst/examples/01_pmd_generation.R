library(pmdplan)
data("affect", package = "pmdplan")
items <- c(paste0("x", 1:4), paste0("y", 1:4))
subsets <- list(A = c("x1", "y1"), B = c("x2", "y2"),
                C = c("x3", "y3"), D = c("x4", "y4"))

# Measure three of four subsets at each occasion.
x <- pmd_forms(affect, "N_index", "time", items = items,
  design = "matrix", subsets = subsets, subsets_per_form = 3)
head(x$data)

# Keep x1 and y1 measured in every form.
anchor <- pmd_forms(affect, "N_index", "time", items = items,
  design = "anchor", subsets = subsets, subsets_per_form = 3,
  anchors = c("x1", "y1"))
anchor$specification$forms

data("affect", package = "pmdplan")
items <- c(paste0("x", 1:4), paste0("y", 1:4))

# Compare two designs retaining 57 of 76 occasions per participant.
consistent <- pmd_occasions(affect, "N_index", "time", pmd_item = items,
  design = "consistent", first_prop = 0.5, interval = 1)
truncated <- pmd_occasions(affect, "N_index", "time", pmd_item = items,
  design = "truncated", first_prop = 0.75)
head(consistent$subject_schedule)
head(truncated$subject_schedule)

# Use the eight item names in affect; response data are not needed.
items <- c(paste0("x", 1:4), paste0("y", 1:4))
pmd_items <- c(paste0("x", 1:3), paste0("y", 1:3))
item_schedule <- pmd_schedule(
  N = 60, TT = 76, items = items, pmd_items = pmd_items,
  item_design = list(
    design = "matrix",
    subsets = list(A = c("x1", "y1"), B = c("x2", "y2"), C = c("x3", "y3")),
    subsets_per_form = 2
  )
)
head(item_schedule) # x4 and y4 are measured at every occasion.

wave_schedule <- pmd_schedule(
  N = 60, TT = 76, items = items,
  wave_design = list(design = "balanced", first_prop = 0.5, interval = 1)
)
head(wave_schedule)
