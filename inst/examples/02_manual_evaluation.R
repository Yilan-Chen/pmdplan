# Illustrative supplied results, not generated or fitted data.
library(pmdplan)
population_value <- data.frame(parameter="beta", value=.2)
estimates <- data.frame(design="anchor25", replication=1:4,
  parameter="beta", estimate=c(.19,.22,.50,NA_real_),
  sd=c(.05,.05,.05,NA_real_), lower=c(.09,.12,.40,NA_real_),
  upper=c(.29,.32,.60,NA_real_), max_psr=c(1.01,1.03,1.12,NA_real_))
# The fourth row preserves the failed replication. No runs or condition input.
performance <- evaluate_pmd(estimates, population_value, cutoff=1.05,
  max_abs_relative_bias=.1)
stopifnot(performance$convergence_rate == .5)
print(performance)
attr(performance, "replications")
attr(performance, "design_summary")
