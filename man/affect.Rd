\name{affect}
\alias{affect}
\docType{data}
\title{Repeated Measurements of Positive and Negative Affect}
\description{
A baseline dataset containing eight emotion ratings from 125 participants in the experience sampling study by Rowland and Wenzel (2020). Each participant contributes their first 76 retained measurements. Negative affect comprises angry, anxious, depressed and sad; positive affect comprises happy, excited, relaxed and satisfied. All items were rated on sliders from 0 (not at all) to 100 (very much).
}
\usage{
affect
}
\format{
A data frame with 9500 rows and 10 variables:
\describe{
  \item{N_index}{Participant identifier. There are 125 distinct identifiers,
retained from the source data; the identifiers are not consecutive.}
  \item{x1}{Happy: positive affect rating (0--100).}
  \item{x2}{Excited: positive affect rating (0--100).}
  \item{x3}{Relaxed: positive affect rating (0--100).}
  \item{x4}{Satisfied: positive affect rating (0--100).}
  \item{y1}{Angry: negative affect rating (0--100).}
  \item{y2}{Anxious: negative affect rating (0--100).}
  \item{y3}{Depressed: negative affect rating (0--100).}
  \item{y4}{Sad: negative affect rating (0--100).}
  \item{time}{Measurement order within each participant, from 1 to 76. This is
an occasion index, not a timestamp or elapsed time.}
}
}
\details{
The supplied baseline file was prepared from \file{data_affect.csv}. Occasions with all eight emotion ratings missing were removed before numbering each participant's remaining occasions and retaining the first 76. The original \code{subjno} column became \code{N_index}; \code{emo1_m}--\code{emo4_m} became \code{x1}--\code{x4}, and \code{emo5_m}--\code{emo8_m} became \code{y1}--\code{y4}. These item meanings follow the original study codebook.

The included data preserve the supplied \file{data1.dat} values and column order. Ratings are on their original 0--100 scale, without centering, standardization or imputation. All 9500 rows have complete item responses; no planned missingness has been imposed. Use \code{id = "N_index"} and \code{time = "time"} with the PMD functions. Baseline refers to the reference dataset before applying PMD, not to a single study wave or treatment group.
}
\source{
openESM, Rowland (2020): \url{https://openesmdata.org/datasets/0006_rowland/}.

Original study data: \url{https://osf.io/jmz2n/}. Original variable codebook: \url{https://osf.io/5t4yg/}.
}
\references{
Rowland, Z., and Wenzel, M. (2020). Mindfulness and affect-network density: does mindfulness facilitate disengagement from affective experiences in daily life? \emph{Mindfulness}, \bold{11}, 1253--1266.
\doi{10.1007/s12671-020-01335-4}.
}
\section{License}{
The data are supplied under the Creative Commons Attribution-NonCommercial 4.0 International license reported by openESM: \url{https://creativecommons.org/licenses/by-nc/4.0/}. Attribute the study and source, retain the license notice and identify the preprocessing described above. The data license is separate from the GPL-3 license of the package's software; see the package LICENSE file.
}
\examples{
data("affect", package = "pmdplan")
head(affect)
dim(affect)
}
\keyword{datasets}
