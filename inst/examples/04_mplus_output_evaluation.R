library(pmdplan)
# Supply your own files. Neither the output nor the edited map is included.
file <- "my_model.out"
map_file <- file.path("parameter_map", "map.csv")
if (file.exists(file) && file.exists(map_file)) {
  map <- utils::read.csv(map_file, colClasses = "character", check.names = FALSE)
  estimates <- read_mplus_estimates(file, map = map, n_factors = 2)
  print(estimates)
}
# Use obtain_map(file, path = "parameter_map") first, then edit parameter names.
# For evaluation, supply the population values from your own simulation.
