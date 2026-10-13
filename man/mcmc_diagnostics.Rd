\name{mcmc_diagnostics}
\alias{mcmc_diagnostics}
\title{Posterior Summaries and Unsplit PSR for One Fit}
\description{Summarize an existing mcmc.list and calculate the unsplit variance-ratio PSR. No ESS or model fitting is performed.}
\usage{
mcmc_diagnostics(draws, burnin = 0, prob = 0.95,
  n_factors = NULL, cutoff = NULL)
}
\arguments{
\item{draws}{An object of class coda::mcmc.list representing one fitted replication. Each chain has numeric rows of stored iterations and identically named parameter columns. Chain dimensions and column order must agree. Example: coda::mcmc.list(coda::mcmc(chain1), coda::mcmc(chain2)), where chain1 and chain2 are numeric matrices. For several replications use evaluate_pmd(source="mcmc"). Include all sampled parameters whose PSR should govern convergence.}
\item{burnin}{A nonnegative integer number of stored rows discarded from the beginning of each chain, default 0. At least two rows must remain. No automatic splitting, thinning or additional half-chain removal occurs.}
\item{prob}{A numeric value strictly between 0 and 1, default 0.95. Gives the mass of the equal-tailed credible interval; e.g. 0.90 uses the 0.05 and 0.95 quantiles.}
\item{n_factors}{A nonnegative integer specifying the number of factors, or NULL. Required unless cutoff is explicit. One substantive construct present at both within and between levels counts as one. The default cutoff is 1.05 for n_factors=1 and 1.10 for every other count, including counts greater than 2.}
\item{cutoff}{A finite numeric value of at least 1, or NULL. An explicit value overrides factor defaults. A fit converges only when its maximum PSR is finite, positive and strictly below the cutoff.}
}
\details{
For m chains of n retained draws, W is the mean of sample variances within chains and B is n times the sample variance of chain means. The calculation is
\deqn{\widehat{V} = (n-1)W/n + B/n, \qquad PSR = \sqrt{\widehat{V}/W}.}
It uses no chain splitting, rank normalization, degrees-of-freedom adjustment, rounding or clamping to 1. Therefore it is not coda::gelman.diag or posterior::rhat. All retained supplied draws contribute to PSR. Median, sample SD and type-7 equal-tailed quantiles use the pooled retained draws. The estimate column is the posterior median; chain means in the PSR formula remain means.

At least two chains are needed for PSR. One chain can still yield posterior summaries but cannot pass convergence. Nonfinite draws make that parameter's summaries/PSR unavailable; zero W produces unavailable or infinite PSR. If any parameter PSR is missing, max_psr is missing and the fit does not converge. Exclude fixed, unsampled constants from chain columns. No ESS or MCSE is computed.
}
\value{A parameter-level data.frame containing parameter, estimate, sd, lower, upper, psr, chains, draws_per_chain, message, max_psr, converged, cutoff and n_factors. max_psr and the whole-fit convergence flag repeat on each parameter row.}
\examples{
# Illustrative draws created here, not posterior results for affect.
if (requireNamespace("coda", quietly = TRUE)) {
  draws <- coda::mcmc.list(coda::mcmc(cbind(theta = 1:4)),
                         coda::mcmc(cbind(theta = 2:5)))
  mcmc_diagnostics(draws, n_factors = 1)
}
}
