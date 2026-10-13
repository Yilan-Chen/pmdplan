\name{pmd_occasions}
\alias{pmd_occasions}
\title{Apply Wave-Level Planned Missingness}
\description{Applies wave-level planned missingness to selected variables.}
\usage{
pmd_occasions(data, id, time, pmd_item,
  design = c("balanced", "consistent", "truncated"),
  first_prop = 0.5, interval = 1, seed = 1)
}
\arguments{
\item{data}{A data frame in which each row represents one participant at one measurement occasion.}
\item{id}{The name of the participant identifier column in \code{data}, for example \code{id = "N_index"}. Participant identifiers may be numeric, character, or factor values.}
\item{time}{The name of the measurement time column in \code{data}, for example \code{time = "time"}. This column may be numeric, character, factor, \code{Date}, or \code{POSIXct}. Character labels sort alphabetically; factors follow their level order.}
\item{pmd_item}{A vector of variable names specifying where planned missingness is applied, for example \code{c("x1", "y1")}.}
\item{design}{A character string specifying \code{"balanced"} (default), \code{"consistent"}, or \code{"truncated"}. The balanced design assigns participants as evenly as possible to \code{interval + 1} groups with different measurement occasions in Phase II. The consistent design uses the same measurement occasions in Phase II for all participants. The truncated design ends measurement after the initial period of consecutive measurement.}
\item{first_prop}{A numeric value between 0 and 1 specifying the proportion of time points allocated to consecutive measurement in Phase I. Defaults to \code{0.5}. For each participant, this period contains \code{floor(TT * first_prop)} time points, where \code{TT} is their number of rows. For \code{"truncated"}, measurement ends after this period.}
\item{interval}{A nonnegative integer specifying the number of unmeasured occasions between measurements in Phase II. Defaults to \code{1}, which measures every second occasion; \code{2} measures every third occasion, and \code{0} measures every occasion. Used only with \code{"balanced"} and \code{"consistent"}.}
\item{seed}{A nonnegative integer specifying the random seed. Defaults to \code{1}.}
}
\details{
Occasions follow each participant's time-ordered rows. Participants may have different measurement times and numbers of occasions. The original row order is retained.

In Phase II, the consistent design measures positions \code{interval + 1}, \code{2 * (interval + 1)}, and so on. The balanced design shifts this pattern across randomly assigned groups whose sizes differ by at most one. For the truncated design, only \code{first_prop} determines the number of retained occasions; do not supply \code{interval}. For equal-burden comparisons, choose \code{first_prop} accordingly and check \code{subject_schedule$n_observed} before fitting models. Equal \code{first_prop} values do not imply equal measurement counts across designs; \code{\link{evaluate_pmd}} does not check this.
}
\value{An object of class \code{"pmd_data"}; see \code{\link{apply_pmd}}. Additional components are \code{subject_schedule} (each participant's group and numbers of measured and omitted occasions) and \code{specification} (design settings).}
\references{Liu, Y., Luo, X., and Liu, H. (2026). Planned measurement-missing designs in intensive longitudinal studies: How well do they recover power and parameter estimates? \emph{Structural Equation Modeling: A Multidisciplinary Journal}, \bold{33}(4), 531--541. \doi{10.1080/10705511.2026.2625171}.}
\seealso{\code{\link{pmd_schedule}}, \code{\link{pmd_forms}}, \code{\link{apply_pmd}}}
\examples{
data("affect", package = "pmdplan")
items <- c(paste0("x", 1:4), paste0("y", 1:4))

# Compare two designs retaining 57 of 76 occasions per participant.
consistent <- pmd_occasions(affect, "N_index", "time", pmd_item = items,
  design = "consistent", first_prop = 0.5, interval = 1)
truncated <- pmd_occasions(affect, "N_index", "time", pmd_item = items,
  design = "truncated", first_prop = 0.75)
head(consistent$subject_schedule)
head(truncated$subject_schedule)
}
