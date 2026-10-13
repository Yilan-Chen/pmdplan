\name{pmd_batch}
\alias{pmd_batch}
\title{Apply PMD to Existing Replications in Parallel}
\description{Apply user-selected PMD functions to existing datasets, sharing each supplied replication across all candidate designs. Does not generate complete data or fit models.}
\usage{
pmd_batch(data, designs, metadata = NULL, seed = 1,
  mc.cores = 1, directory = NULL, include_complete = FALSE)
}
\arguments{
\item{data}{A nonempty list containing one existing data.frame per replication. Read external files before calling this function, e.g. lapply(files, readRDS), or use your own reader to assign correct column names to text data. A NULL/invalid entry is recorded as a design_error for every design, rather than omitted.}
\item{designs}{A nonempty, uniquely named list of functions(data, seed), each returning pmd_data. The argument name is designs (plural); a character vector such as c("matrix","balanced") is not accepted. The list names identify designs, while each function fixes the appropriate PMD arguments; pmd_batch supplies data and seed for each replication. The examples below show both a matrix item design and a balanced occasion design. Names are user-chosen labels such as "anchor25" or "consistent"; the function body selects the actual algorithm. Use pmd_forms(design="anchor"), pmd_forms(design="matrix"), pmd_forms(design="random"), or pmd_occasions(design="balanced"), pmd_occasions(design="consistent"), or pmd_occasions(design="truncated"). Set include_complete=TRUE to add the unchanged input as a complete-data baseline.}
\item{metadata}{A data frame with condition and replication, or NULL. Supply one row per data element in the same order, with unique condition/replication pairs. condition is a nonempty user label; replication is a positive integer-valued number. NULL creates condition="condition1" and replication=1,2,... . The row-count check verifies only the number of rows; users must ensure their order matches data.}
\item{seed}{A nonnegative integer specifying the master seed, default 1. Separate PMD seeds are generated for each replication/design; the original R random state is restored. The same data/metadata/design order and seed give the same results with different mc.cores.}
\item{mc.cores}{A positive integer number of replication workers, default 1 on every platform. Windows automatically uses parallel::parLapply with a PSOCK cluster of this size, including one worker when set to 1. macOS/Linux use parallel::mclapply, with serial processing at 1. Designs within each replication run sequentially on the same supplied data, with explicit per-task seeds.}
\item{include_complete}{A logical value, default FALSE. TRUE appends one unchanged input data.frame per replication to data and manifest, labeled design="complete", with object name r1_complete, r2_complete, etc. These rows are automatically analyzed when the result is passed to analyze_mplus. Existing input missingness is retained; no imputation is performed. Complete-data entries are saved as individual RDS files when directory is set. Failed inputs retain a NULL baseline row; a PMD-design failure does not discard a valid complete input. The label complete is reserved when enabled. PMD seeds/results remain identical with this option on or off.}
\item{directory}{A character string specifying a new or empty output directory, e.g. "pmd_exports", or NULL (default) to return results in memory. Saves one RDS for each successful replication/design combination plus manifest.csv. No combined pmd_batch.rds is written, avoiding duplicate storage of the datasets. The returned in-memory object still contains all results. Directory creation uses showWarnings=TRUE and failure stops clearly. Existing nonempty destinations are rejected.}
}
\value{A list with data (named pmd_data objects for PMD, unchanged data.frames for complete baselines, NULL for failures), manifest (condition, replication, design, object, seed, status, error, file), burden (condition, replication, design, planned_missing_prop, original_missing_prop, total_missing_prop), metadata, seeds and directory. Manifest status is "ok" or "design_error". Files and object names are indexed to avoid unsafe user labels in filenames.}
\details{
The \code{burden} table reports missingness proportions for each successful PMD dataset. Designs are not automatically matched on measurement counts or planned missingness proportions. For equal-burden comparisons, use the same PMD items and check these quantities before fitting models; \code{\link{evaluate_pmd}} does not perform this check.

The returned data component is a flat list, with one entry per replication/design combination. For 500 replications and three designs it has 1500 entries, not 500 lists of three data.frames. Each successful entry is a pmd_data object; use result$data[[1]]$data for its data.frame. Failed entries are NULL. With include_complete=TRUE, the same example has 2000 flat entries: three PMD objects and one complete data.frame per replication. Complete rows have seed=NA and no entry in burden, which describes PMD designs only. With the default FALSE, complete inputs are not additionally returned. Missing cells are R NA values, also when saved as RDS.

The two design functions in the examples are templates: matrix selects the item-level PMD algorithm via pmd_forms(design="matrix"), whereas balanced selects the time-level algorithm via pmd_occasions(design = "balanced"). Change items or pmd_item, subsets, subsets_per_form, interval and other arguments inside these functions to specify your study. The names on the left are user-chosen labels; function bodies specify the actual design. Each design receives the original supplied replication, so missingness is not applied cumulatively across designs.

Windows workers receive the caller's library paths, RNG kind and ordinarily referenced R objects/functions, including items and subsets defined outside a design function. Required packages must already be installed. Objects looked up dynamically by constructed names should instead be explicitly captured in the design function's enclosing environment. Clusters are closed on return or error.

With two replications and two successful designs, disk output contains r1_d1.rds, r1_d2.rds, r2_d1.rds, r2_d2.rds and manifest.csv. The r/d numbers refer to input-list positions; manifest.csv maps them to condition, replication, design, seed, status and file. Each PMD RDS contains a pmd_data object: use readRDS(path)$data for the data.frame or readRDS(path)$mask for its mask. A complete-baseline RDS contains the original data.frame directly. Failures have no individual RDS; they remain in manifest.csv and as NULL in the returned data list. Read files listed for successful manifest rows to reload results; a combined RDS is not necessary. Users who explicitly want an archive of the entire returned list may call saveRDS on that list themselves.

For batch Mplus analysis, pass the returned object directly to \code{\link{analyze_mplus}}, which exports its own analysis data files. For text data used in other external software, read the saved object, select the required columns from its data component and call utils::write.table yourself. The example below writes a space-delimited .dat file without row or column names. For Mplus, export numeric columns (explicitly recode character/factor variables if needed), choose a missing code that does not occur in observed data, and specify the same column order and missing code in the model input. The package does not provide a separate data-export function.

No raw-data generator or analysis callback is accepted. Apply PMD here, analyze the resulting datasets with analyze_mplus or in your chosen software, then use evaluate_pmd with source="mplus", "mcmc" or "manual". Preserve condition/design/replication identifiers throughout. Failed replications must remain in the later evaluation manifest.
}
\seealso{\code{\link{pmd_forms}}, \code{\link{pmd_occasions}}, \code{\link{evaluate_pmd}}}
\examples{
data("affect", package = "pmdplan")
items <- c(paste0("x", 1:4), paste0("y", 1:4))
subsets <- list(A = c("x1", "y1"), B = c("x2", "y2"),
                C = c("x3", "y3"), D = c("x4", "y4"))
designs <- list(
  matrix = function(data, seed) {
    pmd_forms(data, "N_index", "time", items = items,
      design = "matrix", subsets = subsets, subsets_per_form = 3, seed = seed)
  },
  balanced = function(data, seed) {
    pmd_occasions(data, "N_index", "time", pmd_item = items,
      design = "balanced", first_prop = 0.5, interval = 1, seed = seed)
  }
)
# One empirical dataset; for simulations, supply one list entry per replication.
batch <- pmd_batch(list(affect), designs, include_complete = TRUE)
batch$manifest
head(batch$data[[1]]$data)
}
