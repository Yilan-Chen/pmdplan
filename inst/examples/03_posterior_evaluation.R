library(pmdplan)
if (requireNamespace("coda", quietly=TRUE)) {
  # Tiny illustrative chain matrices; replace them with your saved posterior chains.
  one_fit <- coda::mcmc.list(coda::mcmc(cbind(theta=1:4)),
                           coda::mcmc(cbind(theta=2:5)))
  draws <- list(one_fit, one_fit)
  metadata <- data.frame(condition="c1", design="matrix", replication=1:2)
  population_value <- data.frame(condition="c1", parameter="theta", value=3)
  performance <- evaluate_pmd(draws, population_value, source="mcmc", metadata=metadata,
    n_factors=1, prob=.95, burnin=0, mc.cores=1)
  stopifnot(performance$convergence_rate == 1)
  attr(performance, "diagnostics")[[1]]
}
