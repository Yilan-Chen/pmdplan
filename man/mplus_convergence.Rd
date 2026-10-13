\name{mplus_convergence}
\alias{mplus_convergence}
\title{Check Mplus Convergence from TECH8 and Error Messages}
\description{Combine the final native PSR, error-list check and final iteration limit in a single convergence rule.}
\usage{
mplus_convergence(out, cutoff = NULL, n_factors = NULL,
  max_iterations = 50000)
}
\arguments{
\item{out}{A list, usually from MplusAutomation::readModels(), containing errors and tech8$psr. A nonempty tech8$psr must be the standard data.frame with numeric columns named exactly psr and iteration. These columns are read directly; no alternative names, case conversion, matrix/vector conversion or duplicate-column checks are used. NULL or a zero-row table is treated as unavailable.}
\item{cutoff}{A finite numeric value of at least 1, or NULL. An explicit value overrides the factor-based default. With NULL, n_factors=1 uses 1.05; every other count uses 1.10. The final PSR must be strictly below cutoff.}
\item{n_factors}{A nonnegative integer specifying the number of factors, or NULL. One construct represented at within and between levels counts as one factor. Required unless cutoff is explicit.}
\item{max_iterations}{A positive integer specifying the iteration limit, default 50000. The final iteration recorded in TECH8 must be strictly below this limit; equality fails. For example, use 80000 when that is the intended limit. This is a check on existing output; it does not set or run Mplus iterations.}
}
\details{
The final row of TECH8 supplies the native maximum PSR at that checkpoint and its iteration number. Earlier, larger PSRs do not replace the final value. The reader uses tech8$psr$psr and tech8$psr$iteration directly.

The error flag is computed using the length of out$errors before unlisting: if that length is greater than one, errors_flag is FALSE only when the final PSR is below cutoff and the error text does not contain THE MODEL ESTIMATION DID NOT TERMINATE NORMALLY. Otherwise errors_flag is TRUE. When length(out$errors) is zero or one, errors_flag is FALSE. In particular, a single list element containing multiple strings still counts as one element.

Convergence requires all of the following: a nonempty available PSR result, a finite final PSR below cutoff, errors_flag=FALSE, and a finite final iteration below max_iterations. Missing, empty or nonfinite diagnostics cannot establish convergence. If iteration is unavailable, last_iteration and iteration_limit_reached are NA and converged is FALSE.

For standard nonempty output with finite diagnostic values, cutoff=1.1 and max_iterations=80000 reproduce the supplied 1.1/80000 rejection rule. The package defaults remain factor-dependent PSR limits and max_iterations=50000. Unavailable or nonfinite values are explicitly treated as nonconverged; a direct if() expression on missing values can instead produce an error.

There is no alternative rule selector. terminated_abnormally is reported, but it influences convergence only through the error-list rule above. An out$converged field is not used to add another rejection condition. This function reads native diagnostics; it does not compute posterior-chain PSR. See \code{\link{mcmc_diagnostics}} for mcmc.list input.
}
\value{A one-row data.frame containing converged, last_psr, last_iteration, errors_flag, terminated_abnormally, iteration_limit_reached, max_iterations, cutoff, n_factors and cutoff_source. cutoff_source is "factor_default" or "user".}
\examples{
# An illustrative diagnostic record, not an imported Mplus output.
out <- list(
  tech8 = list(psr = data.frame(
    iteration = c(1000, 2000), psr = c(1.2, 1.07))),
  errors = list())
mplus_convergence(out, n_factors = 1) # Default cutoff 1.05: fails.
mplus_convergence(out, n_factors = 2) # Default cutoff 1.10: passes.
}
