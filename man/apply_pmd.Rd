\name{apply_pmd}
\alias{apply_pmd}
\title{Apply a Planned Missingness Mask}
\description{Applies a planned missingness pattern to selected variables using a logical matrix. Entries marked as \code{TRUE} are set to \code{NA}.}
\usage{
apply_pmd(data, mask, id, time, items, design = "custom")
}
\arguments{
\item{data}{A data frame in which each row represents one participant at one measurement occasion.}
\item{mask}{A logical matrix with \code{nrow(data)} rows and \code{length(items)} columns. Rows correspond to rows of \code{data}, and columns correspond to the variables in \code{items}, in the same order. Data entries corresponding to \code{TRUE} are set to \code{NA}; those corresponding to \code{FALSE} are left unchanged. The matrix must not contain \code{NA}. If column names are supplied, they must match \code{items} in the same order.}
\item{id}{The name of the participant identifier column in \code{data}, for example \code{id = "N_index"}. Participant identifiers may be numeric, character, or factor values.}
\item{time}{The name of the measurement time column in \code{data}, for example \code{time = "time"}. This column may be numeric, character, factor, \code{Date}, or \code{POSIXct}.}
\item{items}{A vector of variable names specifying where planned missingness is applied, for example \code{c("x1", "y1")}.}
\item{design}{A single character string specifying a name for the planned missingness design. Defaults to \code{"custom"}. This name is stored in the output metadata and displayed when the result is printed. It does not affect which entries are set to \code{NA}; these are determined by \code{mask}.}
}
\value{
An object of class \code{"pmd_data"} containing:
\describe{
  \item{data}{The data frame with specific planned missingness.}
  \item{mask}{The logical matrix indicating planned missingness in the variables listed in \code{items}.}
  \item{original_missing}{A logical matrix indicating which entries in the variables listed in \code{items} were missing before applying \code{mask}.}
  \item{metadata}{A data frame containing \code{design}, \code{planned_missing_prop}, \code{original_missing_prop}, and \code{total_missing_prop}. These record the design name, the proportion of entries marked as planned missing, the proportion originally missing, and the proportion missing after applying the mask, respectively. All proportions are calculated using only the variables listed in \code{items}. Entries that are both originally missing and marked as planned missing are counted only once in \code{total_missing_prop}.}
  \item{id, time, items}{The column names supplied through the corresponding arguments.}
}
}
