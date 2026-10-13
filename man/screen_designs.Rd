\name{screen_designs}
\alias{screen_designs}
\title{Screen Designs Against Explicit Criteria}
\description{Require all selected parameters to meet user criteria within each condition. Missing metrics fail the requested criterion.}
\usage{
screen_designs(performance, parameters, ...,
                           max_abs_relative_bias = 0.10, min_coverage = 0.91,
                           max_coverage = 0.98, min_power = 0.80,
                           min_typeI_error = 0.025, max_typeI_error = 0.075)
}
\arguments{
\item{performance}{A data frame returned by evaluate_pmd(). Active power or type I error criteria additionally require a numeric reference column and their corresponding metric columns.}
\item{parameters}{A vector of parameter names matching those in \code{performance}, for example \code{c("beta", "variance")}. Every requested parameter must satisfy each applicable active criterion.}
\item{...}{Must be empty. Supply every screening threshold by its full argument name. Unsupported or positional threshold arguments are rejected.}
\item{max_abs_relative_bias}{A nonnegative finite numeric value (default 0.10), or NULL to disable screening, specifying the maximum absolute relative bias as a proportion. Example: 0.1 allows relative bias in [-0.1,0.1], including endpoints.}
\item{min_coverage}{A numeric value between zero and one, or NULL, giving the inclusive lower coverage bound for the population target. Defaults to 0.91. NULL disables only this lower bound.}
\item{max_coverage}{A numeric value between zero and one, or NULL, giving the inclusive upper coverage bound for the population target. Defaults to 0.98. NULL disables only this upper bound. When both bounds are given, min_coverage must not exceed max_coverage.}
\item{min_power}{A numeric value between zero and one, or NULL, giving the inclusive minimum power for nonzero population value. Defaults to 0.80. NULL disables power screening. Not applied to zero population value.}
\item{min_typeI_error}{A numeric value between zero and one, or NULL, giving the inclusive minimum type I error rate for exactly zero population value. Defaults to 0.025. NULL disables only this lower bound.}
\item{max_typeI_error}{A numeric value between zero and one, or NULL, giving the inclusive maximum type I error rate for exactly zero population value. Defaults to 0.075. NULL disables only this upper bound. When both bounds are given, min_typeI_error must not exceed max_typeI_error. Type I error screening is not applied to nonzero population value.}
}
\value{A data.frame with condition, design, eligible and reason. This is screening, not a universal optimum or an automatic cost model.}
\details{evaluate_pmd() already screens all population_value targets automatically. Call this function to rescreen selected parameters or change the criteria; it returns a separate table and does not change the original evaluation. By default, coverage must lie in [0.91, 0.98], including both endpoints. In addition, nonzero population value requires power >= 0.80; exactly zero population value requires typeI_error in [0.025, 0.075], including both endpoints. Classification uses reference, not relative_bias_defined. Each parameter is checked only against the applicable rejection metric. Missing or invalid applicable rates fail active criteria; inactive or inapplicable metrics are ignored. Bounds can be customized independently; set both min_coverage and max_coverage to NULL to disable coverage screening. Unavailable coverage fails any active coverage criterion. All reference values represent population parameters. This range screens the realized proportion of intervals containing the population value across replications; it does not change the nominal probability level used to construct each interval. The relative-bias criterion is disabled when max_abs_relative_bias is NULL. Parameters explicitly excluded using evaluate_pmd(exclude_rbias=...) have relative_bias_excluded=TRUE and skip this criterion even when a limit is supplied. At an exactly zero reference, relative bias remains NA; without explicit exclusion it fails an active relative-bias criterion. A parameter with n_valid=0 fails screening even with all cutoffs disabled. RMSE is reported without a cutoff and is not used by this function. Every selected parameter must meet every active criterion. PSR cutoffs for all three input sources apply to individual fits before evaluation; they are not design-screening thresholds. Other calculated metrics, including bias and convergence_rate, have no separate threshold argument in this function.}

\examples{
# Illustrative performance summaries, not fitted results for affect.
performance <- data.frame(condition = "example", design = c("matrix", "balanced"),
  parameter = "theta", relative_bias = c(.02, .03), reference = 1,
  power = c(.85, .90), typeI_error = NA_real_, coverage = c(.90, .95))
screen_designs(performance, "theta")
screen_designs(performance, "theta", min_coverage = 0.90)
}
