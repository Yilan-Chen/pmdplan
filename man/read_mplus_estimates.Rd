\name{read_mplus_estimates}
\alias{read_mplus_estimates}
\title{Read Existing Mplus Estimates and Native PSR}
\description{Use MplusAutomation to read one fitted output, match parameter rows, and check convergence using PSR, errors and the iteration limit. Does not execute Mplus.}
\usage{
read_mplus_estimates(file, map, cutoff = NULL,
  n_factors = NULL, max_iterations = 50000)
}
\arguments{
\item{file}{A character string specifying an existing .out file representing one fitted replication, e.g. "rep1.out". For multiple files use evaluate_pmd(source="mplus"). A many-replication Monte Carlo summary is not a substitute for individual estimates and PSRs.}
\item{map}{A data frame mapping parameter names to Mplus output rows. First call \code{\link{obtain_map}} with an output file and a directory path. It saves map.csv with a blank parameter column. Fill in unique custom names only for parameters to evaluate; leave all other rows blank. Read the edited CSV with \code{utils::read.csv("map.csv", colClasses="character", check.names=FALSE)} and pass the data.frame here. Blank, whitespace-only or NA parameter names are ignored; at least one named row is required. Leading/trailing whitespace in names is removed. Required columns are parameter, paramHeader and param. Keep BetweenWithin when present in the generated table: it participates in matching and distinguishes the Within and Between levels. Do not rename or edit identifier columns, and do not add population values or notes to map. All columns except parameter identify output rows exactly. Selected names must be unique and match population_value$parameter. Each selected row must match exactly one output row. Selecting parameters does not restrict the model-level convergence check.}
\item{cutoff}{A finite numeric value of at least 1, or NULL. Explicit values override defaults. With NULL, n_factors=1 uses 1.05; every other valid count uses 1.10. The final native PSR must be finite and strictly below cutoff.}
\item{max_iterations}{A positive integer specifying the iteration limit, default 50000. The final TECH8 iteration must be strictly below it; reaching the limit fails convergence even if PSR is below cutoff. Passed to mplus_convergence. This does not configure or execute Mplus.}
\item{n_factors}{A nonnegative integer specifying the number of factors, or NULL; required when cutoff is NULL. Count substantive constructs, not repeated representations across within/between levels. Zero is permitted for an observed-variable model.}
}
\value{A data.frame with parameter, estimate, sd, lower, upper and converged, plus the mplus_diagnostics attribute containing the native final PSR and iteration, PSR cutoff, iteration limit and error flags.}
\details{
The reader always uses out$parameters$unstandardized and the fixed numeric columns est, posterior_sd, lower_2.5ci and upper_2.5ci. These become estimate, sd, lower and upper in the result. All four columns must exist; missing columns or nonnumeric columns are errors. The reader does not fall back to se, select other parameter tables or reconstruct intervals from SD. For other output formats, prepare a manual input table for evaluate_pmd(source="manual").

MplusAutomation parses existing output; no Mplus executable is needed. Only rows with nonblank parameter names in map are returned. All map columns except parameter participate in matching automatically; no separate matching-column argument is needed. With evaluate_pmd(source="mplus"), map must include the parameters requested in population_value, but need not include other estimated parameters. Use unstandardized population values on the same scale as the extracted estimates. Missing or nonfinite final PSR or iteration does not pass convergence. The error-list rule and iteration limit also apply; see mplus_convergence.
}
\examples{
\dontrun{
# Supply your own Mplus output and an edited map from obtain_map().
# These files are not included in pmdplan.
map <- utils::read.csv("parameter_map/map.csv",
  colClasses = "character", check.names = FALSE)
estimates <- read_mplus_estimates("my_model.out", map = map, n_factors = 2)
}
}
