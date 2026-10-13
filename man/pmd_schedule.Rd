\name{pmd_schedule}
\alias{pmd_schedule}
\title{Generate a PMD Measurement Schedule}
\description{Generates a measurement schedule with planned missingness.}
\usage{
pmd_schedule(x = NULL, N = NULL, TT = NULL, items = NULL,
  pmd_items = items,
  item_design = NULL, wave_design = NULL, seed = 1)
}
\arguments{
\item{x}{An object of class \code{"pmd_data"} returned by \code{\link{apply_pmd}}, \code{\link{pmd_forms}}, or \code{\link{pmd_occasions}}. ID and time values retain their original classes. To extract its schedule, use \code{pmd_schedule(x)} or \code{pmd_schedule(x, items = ...)}. For a \code{\link{pmd_batch}} result, supply an individual PMD object from its \code{data} component.}
\item{N}{A positive integer specifying the number of participants. Required when \code{x} is not supplied.}
\item{TT}{A positive integer giving the number of time points per participant. If this number varies across participants, supply a vector of \code{N} positive integers. Required when \code{x} is not supplied.}
\item{items}{A vector of names for all variables excluding the ID and time variables. With \code{x}, defaults to \code{x$items}. To add variables from \code{x$data}, include their names together with \code{x$items}.}
\item{pmd_items}{A vector of variable names specifying where planned missingness is applied, for example \code{c("x1", "y1")}. Defaults to \code{items}. Items not listed are scheduled at every occasion.}
\item{item_design}{A named list specifying an item-level PMD design:
\describe{
\item{design}{A character string specifying \code{"matrix"} or \code{"random"}. Required. The matrix sampling design rotates forms across measurement occasions; the random sampling design selects a form independently at each occasion with equal probability. To implement an anchor test design, use \code{"matrix"} and include the anchor items in every subset.}
\item{subsets}{A named list containing the item names in each subset. Required. Together, the subsets must cover exactly \code{pmd_items}.}
\item{forms}{A list containing the subset names combined in each form. For example, \code{list(c("A", "B"), c("A", "C"))} defines forms AB and AC. Defaults to \code{NULL}, which constructs forms using \code{subsets_per_form}.}
\item{subsets_per_form}{A positive integer specifying the number of subsets combined in each form. Required when \code{forms} is omitted.}
}}
\item{wave_design}{A named list specifying a wave-level PMD design:
\describe{
\item{design}{A character string specifying \code{"balanced"}, \code{"consistent"}, or \code{"truncated"}. Required. The balanced design assigns participants as evenly as possible to \code{interval + 1} groups with different measurement occasions following an initial period of consecutive measurement. The consistent design uses the same occasion pattern for all participants. The truncated design ends measurement after the initial consecutive measurement period.}
\item{first_prop}{A numeric value between 0 and 1 specifying the proportion of time points allocated to consecutive measurement in Phase I. Defaults to \code{0.5}. This period contains \code{floor(TT * first_prop)} time points per participant. For \code{"truncated"}, measurement ends after this period.}
\item{interval}{A nonnegative integer specifying the number of unmeasured occasions between measurements in Phase II, for \code{"balanced"} and \code{"consistent"}. Defaults to \code{1}: measure every second occasion. Use \code{2} for every third occasion, or \code{0} for every occasion.}
}}
\item{seed}{A nonnegative integer specifying the random seed. Defaults to \code{1}.}
}
\value{A data frame with one row per participant and measurement occasion. For each item, \code{TRUE} indicates that measurement is required; \code{FALSE} indicates that it is not required.}
\details{To generate a new schedule, supply \code{item_design} for item-level planned missingness or \code{wave_design} for wave-level planned missingness, but not both. To extract an existing schedule, supply \code{x}.

When \code{forms} is omitted, forms comprise all combinations of \code{subsets_per_form} subsets. The matrix sampling design rotates these forms across measurement occasions in a randomly chosen order; the random sampling design selects a form independently at each occasion. To limit memory use, automatic construction of matrix forms stops if the number of combinations exceeds 10000. In this case, supply \code{forms} as a list of the subset combinations to use.}
\references{
Chen, Y., and Liu, H. (2026). Planned missingness in intensive longitudinal studies: Extensions and comparisons of multiform designs. \emph{Behavior Research Methods}, \bold{58}, Article 215. \doi{10.3758/s13428-026-03035-8}.

Liu, Y., Luo, X., and Liu, H. (2026). Planned measurement-missing designs in intensive longitudinal studies: How well do they recover power and parameter estimates? \emph{Structural Equation Modeling: A Multidisciplinary Journal}, \bold{33}(4), 531--541. \doi{10.1080/10705511.2026.2625171}.
}
\seealso{\code{\link{pmd_forms}}, \code{\link{pmd_occasions}}, \code{\link{pmdplan_getting_started}}}
\examples{
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
}
