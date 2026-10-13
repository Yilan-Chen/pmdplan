library(pmdplan)
# Prepare a simulation using the default model and population values.
# This creates Mplus input, rather than using an empirical dataset.
folder <- tempfile("mplus-generation-")
prepared <- generate_mplus_data(N = 100, TT = 76, replication = 10,
  path = folder, run = FALSE)
prepared$input
unlink(folder, recursive = TRUE)
