\name{obtain_map}
\alias{obtain_map}
\title{Create an Editable Mplus Parameter Map}
\description{Extract Mplus parameter identifiers and save map.csv with a blank parameter column for users to name the parameters they want to evaluate. Does not run Mplus or evaluate convergence.}
\usage{obtain_map(file, path = ".")}
\arguments{
\item{file}{A character string specifying an existing per-replication Mplus .out file containing the complete unstandardized parameter table, for example "anchor_1.out".}
\item{path}{A character string specifying the output directory, default "." (the current working directory). The filename is always map.csv. Missing directories are created with showWarnings=TRUE. An existing map.csv in this directory is overwritten, so generate the template before editing parameter names.}
}
\value{The data.frame written to map.csv, with one row per output parameter in output order. The first column, parameter, is initially blank. Other columns are paramHeader and param, plus BetweenWithin if present in the output. No labels are concatenated. Estimates, population values, Group and LatentClass are not included.}
\details{
Open map.csv and type a unique custom name (for example, beta) into parameter only on rows you want to evaluate. Leave unwanted rows blank; deleting them is optional. Save the edited CSV, read it with \code{utils::read.csv("map.csv", colClasses="character", check.names=FALSE)}, then pass that table to \code{evaluate_pmd(source="mplus", map=map)}. Blank, whitespace-only and NA parameter names are ignored automatically during Mplus reading. At least one row must be named. Use the selected names in the separate population_value table and provide the corresponding population values. The helper does not infer population values.

Keep paramHeader, param and BetweenWithin unchanged. For two-level models, BetweenWithin distinguishes Within and Between parameters with the same header and name and is used automatically by the reader. Single-level output without this column produces only parameter, paramHeader and param. This helper targets parameters identifiable by those columns; it does not construct group or latent class mappings. Output identifiers must uniquely identify each row.

Prepare the map once from a complete output and reuse it for replications with the same parameter identifiers; row order may differ. Every map column except parameter is used for matching, so do not add notes or population values. Manual and MCMC evaluation do not require a map. No PSR cutoff or factor count is needed to generate the template. Evaluation separately requires the fixed Bayesian summary columns and checks convergence.
}
\seealso{\code{\link{evaluate_pmd}}, \code{\link{read_mplus_estimates}}}
\examples{
\dontrun{
# Supply your own Mplus output; this file is not included in pmdplan.
map <- obtain_map("my_model.out", path = "parameter_map")
# In parameter_map/map.csv, name the parameters of interest in the parameter column.
}
}
