\name{evaluate_pmd}
\alias{evaluate_pmd}
\alias{print.pmd_evaluation}
\title{Evaluate Existing Results and Identify Designs Meeting the Criteria}
\description{Read existing Mplus outputs, summarize posterior chains, or accept manual estimates. Determine convergence, calculate evaluation metrics, and automatically identify designs meeting the active cutoffs for all target parameters.}
\usage{
evaluate_pmd(estimates, population_value,
  exclude_rbias = NULL,
  source = c("manual", "mplus", "mcmc"), metadata = NULL,
  n_factors = NULL, cutoff = NULL, map = NULL,
  burnin = 0, prob = 0.95, mc.cores = 1,
  max_abs_relative_bias = 0.10, min_coverage = 0.91,
  max_coverage = 0.98, min_power = 0.80,
  min_typeI_error = 0.025, max_typeI_error = 0.075,
  max_iterations = 50000)

\method{print}{pmd_evaluation}(x, ...)
}
\arguments{
\item{estimates}{A data frame for \code{source="manual"} (default), a character vector of output paths for \code{"mplus"}, or an mcmc.list object or list of mcmc.list objects for \code{"mcmc"}. For manual input, include \code{design}, \code{replication}, \code{parameter}, \code{estimate}, \code{sd}, \code{lower}, \code{upper} and \code{max_psr}. One row represents one parameter in one replication. Optional \code{condition} defaults to \code{"condition1"}. Numeric result columns may contain \code{NA_real_}. For \code{"mplus"}, a character vector of existing per-replication .out paths. For \code{"mcmc"}, a list containing one \code{coda::mcmc.list} per replication; a single mcmc.list is also accepted. Keep missing-file paths or NULL list entries for failed fits. See examples below.}
\item{population_value}{A data frame with \code{parameter} and finite numeric \code{value}. Example: \code{data.frame(parameter=c("beta","intercept"), value=c(0.2,0))}. These rows select target parameters and provide their population values. Optional \code{condition} permits different values or target sets across conditions; without it, the same table applies to all conditions. Rows must be unique by parameter, or condition/parameter when condition is supplied. Values are interpreted as the known or assumed population parameters underlying the repeated datasets.}
\item{exclude_rbias}{A vector of parameter names to exclude from relative-bias calculation and screening, e.g. \code{c("intercept","small_effect")}, or NULL (default) to include every target. Exclusions apply to every condition. Other metrics are unaffected. An exactly zero value always has undefined relative bias (NA); nonzero values, however small, are used without a tolerance rule. When enabling a relative-bias cutoff, explicitly exclude zero-valued targets to skip that otherwise unavailable criterion.}
\item{source}{A character string specifying \code{"manual"}, \code{"mplus"} or \code{"mcmc"}. Reads existing fitted results; does not generate data or fit models.}
\item{metadata}{A data frame for Mplus or MCMC input, with \code{design} and positive integer-valued numeric \code{replication}, one row per input in exactly the same order. Example: \code{data.frame(design=c("anchor","anchor","matrix","matrix"), replication=c(1,2,1,2))}. Optional \code{condition} defaults to \code{"condition1"}. Design and condition are user-chosen nonempty labels, not algorithm selectors. A single applied scenario does not need condition. For manual input omit metadata; these identifiers belong in estimates. Put the shared factor count in n_factors, not metadata.}
\item{n_factors}{A nonnegative integer specifying the number of factors in the model shared by all replications, or NULL. One construct present at within and between levels counts as one factor. With cutoff=NULL, 1 selects 1.05; all other counts, including values above 2, select 1.10. Supply n_factors or cutoff. Explicit cutoff works without n_factors.}
\item{cutoff}{A finite numeric value of at least 1, or NULL. Shared PSR cutoff; overrides factor defaults. Convergence requires finite positive max_psr strictly below it. Equality, NA and positive infinity do not pass. Manual max_psr is supplied for the whole fit and is not recomputed across parameters or replications.}
\item{max_iterations}{A positive integer specifying the iteration limit for Mplus results, default 50000, shared by all fitted replications in this call. The final TECH8 iteration must be below this limit; equality fails. Example: max_iterations=80000. It checks existing output and does not configure Mplus. Manual and mcmc input are unaffected.}
\item{map}{A data frame mapping parameter names to Mplus output rows. First call \code{\link{obtain_map}} with an output file and a directory path. It saves map.csv with a blank parameter column. Fill in unique custom names only for parameters to evaluate; leave all other rows blank. Read the edited CSV with \code{utils::read.csv("map.csv", colClasses="character", check.names=FALSE)} and pass the data.frame here. Blank, whitespace-only or NA parameter names are ignored; at least one named row is required. Leading/trailing whitespace in names is removed. Required columns are parameter, paramHeader and param. Keep BetweenWithin when present in the generated table: it participates in matching and distinguishes the Within and Between levels. Do not rename or edit identifier columns, and do not add population values or notes to map. All columns except parameter identify output rows exactly. Selected names must be unique and match population_value$parameter. Each selected row must match exactly one output row. Selecting parameters does not restrict the model-level convergence check.}
\item{burnin}{A nonnegative integer specifying the number of stored rows discarded from each MCMC chain, default 0. No automatic half-chain removal or splitting.}
\item{prob}{A numeric value strictly between 0 and 1 specifying the credible-interval probability for MCMC input. Default 0.95 uses pooled posterior 2.5th and 97.5th percentiles; 0.90 uses 5th and 95th percentiles. Does not change manual/Mplus intervals, PSR, or screening cutoffs. Changing prob can change coverage, power and type I error through the bounds.}
\item{mc.cores}{A positive integer specifying the number of replication workers, default 1. Windows uses parallel::parLapply with PSOCK workers; macOS/Linux use parallel::mclapply (serial at 1).}
\item{max_abs_relative_bias}{A finite nonnegative numeric value specifying the relative-bias limit, default 0.10. NULL disables screening. 0.1 permits relative bias in [-0.1,0.1], including endpoints. Targets in exclude_rbias skip this criterion.}
\item{min_coverage, max_coverage}{Numeric values in [0,1] specifying the inclusive coverage bounds, default 0.91 and 0.98. NULL disables the corresponding bound. The lower bound must not exceed the upper bound.}
\item{min_power}{A numeric value in [0,1] specifying the inclusive minimum power for nonzero population values, default 0.80. NULL disables this criterion.}
\item{min_typeI_error, max_typeI_error}{Numeric values in [0,1] specifying the inclusive type I error bounds for zero population values, default 0.025 and 0.075. NULL disables the corresponding bound. The lower bound must not exceed the upper bound.}
\item{x}{An object returned by evaluate_pmd.}
\item{...}{Arguments passed to print.data.frame.}
}
\details{
For comparisons at equal measurement burden, use the same PMD items and check the generated measurement counts and planned missingness proportions before fitting models. These are available in \code{subject_schedule$n_observed} from \code{\link{pmd_occasions}} and \code{burden$planned_missing_prop} from \code{\link{pmd_batch}}. This function does not check or match measurement burden; eligibility refers only to the active estimation-performance criteria.

Manual input has one max_psr per replication across the whole fitted model. For multiple parameter rows, enter it on one row and use NA on the others, or repeat the same number on all rows. Different nonmissing values for one replication are an error. If all are NA, the replication is nonconverged. Supplied converged/status columns are ignored. There is no separate runs input. Keep at least one row with a target name and NA numeric results for a failed replication; a replication absent from estimates cannot enter the denominator.

MplusAutomation::readModels reads one fitted replication per file. The unstandardized table supplies the est column for point estimates. The reader always uses posterior_sd, lower_2.5ci and upper_2.5ci for SD and bounds. All four numeric columns must exist. Missing columns cause an import error; the replication remains in the convergence-rate denominator. There is no fallback to se and no reconstruction of intervals from SD. A single Monte Carlo summary output is not a per-replication file: supply individual outputs or extract a manual table. Mplus convergence requires the final native TECH8 PSR below cutoff, errors_flag=FALSE under the error-list rule, and the final TECH8 iteration below max_iterations. Missing/nonfinite PSR or iteration cannot pass. See \code{\link{mplus_convergence}} for the exact error-list rule. The reader requires a unique matching row; it never chooses an arbitrary level when map is ambiguous. Only the parameters requested in map are extracted; this does not restrict the model-level TECH8 PSR check. Prepare manual inputs for other output formats; \code{\link{read_mplus_estimates}} uses the same fixed table and columns.

For mcmc.list, the point estimate is the median of pooled retained draws. SD is their sample standard deviation; intervals are type-7 equal-tailed quantiles. PSR uses the unsplit variance-ratio formula, including chain means; see \code{\link{mcmc_diagnostics}}. Maximum PSR uses all supplied sampled parameters, including those outside population_value. An unavailable parameter PSR makes the maximum unavailable. No ESS, alternative R-hat or MCSE is computed.

Within evaluation, the replication record is the sole source of convergence status. The estimates attribute does not contain a converged column. Parameter rows are matched to replications using condition, design and replication, so row order and the number of parameters per fit do not affect the match. Inspect attr(result,"replications") for the convergence flags. Diagnostics remain available separately, including the outputs of standalone diagnostic functions.

Convergence rate counts every supplied replication, including failed imports. Other metrics use only converged replications with finite point estimates. Mean SD additionally uses finite SDs; coverage, power and type I error additionally use intervals with both bounds finite. n_valid, n_sd and n_interval show the respective denominators. Across-replication mean_estimate remains a mean: for MCMC, it is the mean of individual posterior medians. Empirical SD is the sample SD of the point estimates across usable replications.

Coverage includes interval endpoints. Reject zero only when lower>0 or upper<0. The rejection rate is power for nonzero population values, or typeI_error for exactly zero values. An endpoint of zero does not reject. Multiple N/T combinations are unnecessary: repeated datasets can address just one applied scenario. Estimates from one actual dataset are not automatically known population values.

All population_value targets within each condition are screened automatically. A design must satisfy every applicable active criterion. Missing required metrics fail the criterion; a target with no usable converged estimates prevents eligibility even with cutoffs disabled. RMSE, bias, convergence_rate, mean_estimate, empirical_sd and mean_sd have no screening cutoffs. In particular, eligibility does not enforce a minimum convergence rate. Use \code{\link{screen_designs}} to rescreen a subset or use different cutoffs. Its separate result does not mutate the original evaluation's eligibility.
}
\value{
A data.frame of class pmd_evaluation, one row per condition/design/target. Columns: reference, relative_bias_defined (nonzero reference), relative_bias_excluded, n_attempted, n_fit_returned, n_converged, n_valid, n_interval, n_sd, convergence_rate, mean_estimate, bias, relative_bias, rmse, empirical_sd, mean_sd, coverage, power and typeI_error. Design-level eligible and reason repeat on its parameter rows.

Printing lists designs meeting all active criteria, or states that none meet them. This refers to the supplied scenario, targets and cutoffs. \code{attr(result,"design_summary")} has one row per condition/design with eligible and reason. \code{attr(result,"replications")} contains each fit's max_psr, cutoff, convergence, status and import error. Attributes estimates, diagnostics, source and screening_cutoffs contain standardized parameter results, per-fit diagnostics, source name and criteria used. For Mplus, attr(result,"diagnostics")[[i]] also reports last_iteration, max_iterations, iteration_limit_reached and errors_flag for replication i.
}
\examples{
# Illustrative estimates, not results fitted to affect.
population_value <- data.frame(parameter = "beta", value = 0.2)
estimates <- data.frame(
  design = "matrix", replication = 1:4, parameter = "beta",
  estimate = c(.19, .22, .50, NA_real_),
  sd = c(.05, .05, .05, NA_real_),
  lower = c(.09, .12, .40, NA_real_),
  upper = c(.29, .32, .60, NA_real_),
  max_psr = c(1.01, 1.03, 1.12, NA_real_))
# Keep the failed replication as a row of missing estimates.
result <- evaluate_pmd(estimates, population_value, cutoff = 1.05)
result
attr(result, "replications")

# Illustrative posterior draws; replace with sampled chains in a study.
if (requireNamespace("coda", quietly = TRUE)) {
  draws <- coda::mcmc.list(
    coda::mcmc(cbind(beta = c(.1, .2, .2, .8))),
    coda::mcmc(cbind(beta = c(.1, .2, .2, .8))))
  metadata <- data.frame(design = "matrix", replication = 1)
  evaluate_pmd(list(draws), population_value, source = "mcmc",
    metadata = metadata, n_factors = 1)
}
}
