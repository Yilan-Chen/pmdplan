\name{pmd_forms}
\alias{pmd_forms}
\title{Apply Multiform Planned Missingness}
\description{Applies item-level planned missingness using combinations of item subsets.}
\usage{
pmd_forms(data, id, time, items = NULL,
  design = c("matrix", "anchor", "random"),
  subsets = NULL, forms = NULL, factors = NULL,
  n_subsets = NULL, subsets_per_form = NULL,
  anchors = NULL, cfa_type = NULL, seed = 1)
}
\arguments{
\item{data}{A data frame in which each row represents one participant at one measurement occasion.}
\item{id}{The name of the participant identifier column in \code{data}, for example \code{id = "N_index"}. Participant identifiers may be numeric, character, or factor values.}
\item{time}{The name of the measurement time column in \code{data}, for example \code{time = "time"}. This column may be numeric, character, factor, \code{Date}, or \code{POSIXct}. Character labels sort alphabetically; factors follow their level order.}
\item{items}{A vector of variable names specifying where planned missingness is applied, for example \code{c("x1", "y1")}. If \code{NULL}, uses the item names in \code{factors}.}
\item{design}{A character string specifying the form allocation rule. \code{"matrix"} (default) rotates forms across occasions. \code{"anchor"} uses the same rotation with an anchor subset in every form. \code{"random"} selects a form independently at each occasion with equal probability.}
\item{subsets}{A named list containing the item names in each subset, for example \code{list(A = c("y1", "y2"), B = c("y3", "y4"))}. Together, the subsets must contain exactly \code{items}; items can be shared across subsets. If \code{NULL}, generates subsets from \code{factors} using the allocation rule described under \code{n_subsets}.}
\item{forms}{A list containing the subset names combined in each form, for example \code{list(c("A", "B"), c("A", "C"))}. If \code{NULL}, matrix and random designs use all combinations of \code{subsets_per_form} subsets; anchor designs combine the anchor subset with \code{subsets_per_form - 1} other subsets.}
\item{factors}{A named list containing the names of the items measuring each factor, for example \code{list(Y = c("y1", "y2", "y3", "y4"), X = c("x1", "x2", "x3", "x4"))}. Required when \code{subsets} is omitted. If \code{items} is also supplied, both must contain the same item names.}
\item{n_subsets}{A positive integer specifying the number of subsets. Required when \code{subsets} is omitted. When subsets are generated, items from each factor are randomly distributed as evenly as possible, with extra items assigned to subsets containing fewer items. For anchor designs, anchors form one subset; the remaining items are distributed among the other \code{n_subsets - 1} subsets using the same rule. With supplied subsets, defaults to \code{length(subsets)}. Generated subsets are named A, B, and so on, or S1, S2, and so on for more than 26 subsets.}
\item{subsets_per_form}{A positive integer specifying the number of subsets in each form, including the anchor subset for \code{design = "anchor"}. Required when \code{forms} is omitted; otherwise ignored.}
\item{anchors}{A vector of anchor item names for \code{design = "anchor"}, for example \code{c("x1", "y1")}. Required unless \code{cfa_type} selects anchors. With supplied \code{subsets}, these items must make up exactly one subset; its name is identified automatically. With generated subsets, these items form the first subset. If supplied, \code{cfa_type} is ignored and no CFA is fitted.}
\item{cfa_type}{A character string specifying \code{"twolevel"} or \code{"singlelevel"}, or \code{NULL} (default). Used only for \code{design = "anchor"} when \code{anchors} is omitted; \code{subsets} must also be omitted. Two-level CFA ranks within-level loadings even when between-level rankings differ. Single-level CFA does not separate the two levels. For each factor, the number of selected anchors is its item count divided by \code{n_subsets}, rounded up. CFA requires numeric continuous items and at least three items per factor.}
\item{seed}{A nonnegative integer specifying the random seed. Defaults to \code{1}.}
}
\details{
Matrix and anchor designs distribute participants as evenly as possible across starting forms and rotate forms across each participant's time-ordered observations.

CFA uses \pkg{lavaan} and selects anchors by absolute standardized loading; ties follow item order in \code{factors}. If fitting or loading extraction fails, the same number of anchors is selected at random within each factor, with a warning listing the selected items.

Generated subsets are nonempty. For anchor designs, enough non-anchor items must remain to fill the other subsets. Automatic matrix or anchor construction is limited to 10000 forms; for larger sets, supply \code{forms}. Random designs sample combinations directly above this limit.
}
\value{An object of class \code{"pmd_data"}; see \code{\link{apply_pmd}}. Additional components are \code{assignment} (the form assigned to each row), \code{loadings} (standardized loadings used for CFA selection, or \code{NULL}), and \code{specification} (subsets, forms, anchors and design settings). The \code{level} column of \code{loadings} is \code{"within"} for two-level CFA and \code{"single"} for single-level CFA. With supplied forms, \code{specification$subsets_per_form} records their individual sizes.}
\references{Chen, Y., and Liu, H. (2026). Planned missingness in intensive longitudinal studies: Extensions and comparisons of multiform designs. \emph{Behavior Research Methods}, \bold{58}, Article 215. \doi{10.3758/s13428-026-03035-8}.}
\seealso{\code{\link{pmd_schedule}}, \code{\link{pmd_occasions}}, \code{\link{apply_pmd}}}
\examples{
data("affect", package = "pmdplan")
items <- c(paste0("x", 1:4), paste0("y", 1:4))
subsets <- list(A = c("x1", "y1"), B = c("x2", "y2"),
                C = c("x3", "y3"), D = c("x4", "y4"))

# Measure three of four subsets at each occasion.
x <- pmd_forms(affect, "N_index", "time", items = items,
  design = "matrix", subsets = subsets, subsets_per_form = 3)
head(x$data)

# Keep x1 and y1 measured in every form.
anchor <- pmd_forms(affect, "N_index", "time", items = items,
  design = "anchor", subsets = subsets, subsets_per_form = 3,
  anchors = c("x1", "y1"))
anchor$specification$forms
}
