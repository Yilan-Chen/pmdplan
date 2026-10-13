\name{generate_mplus_data}
\alias{generate_mplus_data}
\title{Generate Complete Replicated Data with an Editable Mplus Template}
\description{Use explicit default item memberships and population values, or custom Mplus model sections, to generate complete replications. The complete assembled default input is shown below and shipped as a template file.}
\usage{
generate_mplus_data(
    items = list(Sy = c("y1", "y2", "y3"), Sx = c("x1", "x2", "x3"),
                 Ty = c("y1", "y2", "y3"), Tx = c("x1", "x2", "x3")),
    N, TT, replication, modelstring = NULL,
    population_values = list(
      within_loadings = c(y1=.8, y2=.6, y3=.6, x1=.8, x2=.6, x3=.6),
      between_loadings = .7,
      phi_mean = c(phi1=.2, phi2=.2, phi3=.1, phi4=.1),
      phi_variance = .01, mean_logerror = log(.3), var_logerror = .05,
      var_logre = .05, mean_logcov = log(.05), var_logcov = .01,
      intercepts = 0, between_residual_variances = .2, latent_covariance = .2),
    path = "mplus_generation", seed = 1, run = TRUE, Mplus_command = NULL)
}
\arguments{
\item{items}{A named list containing the item names for Sy, Sx, Ty and Tx, as shown in Usage. Sy/Sx specify within-factor items; Ty/Tx specify between-factor items. Each level must list the same observed item set exactly once. Shared names across levels refer to the same columns. No minimum of three items is imposed; Mplus assesses model feasibility. For custom modelstring, a vector of item names is also accepted. Names must be unique ignoring case across observed columns, start with a letter and contain at most eight letters/digits/underscores; id, time and cluster are reserved. With the default template, Sy, Sx, Ty, Tx, NCov, logVSy, logVSx, logcov, phi1--phi4 and err1--errK (K = number of distinct items) are also reserved, ignoring case. Errors list conflicting observed names to rename.}
\item{N}{A positive integer specifying the number of participants (clusters).}
\item{TT}{A positive integer specifying the number of time points per participant.}
\item{replication}{A positive integer specifying the number of generated datasets; all are produced in one Mplus Monte Carlo run.}
\item{modelstring}{A character string with line breaks or a character vector of lines containing ANALYSIS:, MODEL POPULATION: and MODEL:, optionally OUTPUT:. Defaults to NULL, which uses the default template. Provide population values in MODEL POPULATION: and analysis settings in ANALYSIS:. Omit population_values when using a custom modelstring because its MODEL POPULATION: section already specifies those values. Do not include TITLE, MONTECARLO, DATA, VARIABLE or SAVEDATA sections: the function controls names, sample sizes, seed and saving. Each line must be at most 90 characters. Custom syntax must produce complete two-level panels with a CLUSTER column.}
\item{population_values}{An editable named list whose defaults are shown in Usage. A supplied list must contain all 12 fields described below; each entry is an unnamed shared finite value or a complete named vector. Omit this argument (or use NULL) for custom modelstring. mean_logre, latent_means and latent_variances are not accepted because those quantities are fixed for identification in the default template. This is distinct from evaluate_pmd's population_value data.frame.}
\item{path}{A character string specifying a new or empty output directory, default "mplus_generation". Missing directories are created with showWarnings=TRUE.}
\item{seed}{A positive integer specifying the Monte Carlo data-generation seed, default 1.}
\item{run}{A logical value. TRUE runs Mplus after writing the input. FALSE only writes the input and manifest for inspection, without requiring Mplus or MplusAutomation.}
\item{Mplus_command}{A character string specifying the Mplus executable path, for example "/Applications/Mplus/mplus", or NULL for automatic detection by MplusAutomation. Execution requires a locally installed Mplus supporting the model.}
}
\details{
MplusAutomation::runModels uses its default runtime options, with target and optional Mplus_command supplied. The run uses path as its working directory, so its default log is saved there; the caller's working directory is restored.

The default ANALYSIS is TWOLEVEL RANDOM, ESTIMATOR=BAYES, PROCESSORS=2 and FBITERATIONS=100. These are template constants, not separate function arguments. For a different analysis, supply modelstring. The template does perform an embedded analysis; successful generation does not establish its convergence.

Editable population_values fields:
\describe{
\item{within_loadings, between_loadings}{Loadings named by every observed item.}
\item{phi_mean, phi_variance}{Means and nonnegative variances of phi1 (Sy on Sy lag 1), phi2 (Sx on Sx lag 1), phi3 (Sx on Sy lag 1), phi4 (Sy on Sx lag 1).}
\item{mean_logerror, var_logerror}{Mean and nonnegative variance of each item's log within residual variance; name by item.}
\item{var_logre}{Nonnegative variance of logVSy/logVSx, with keys Sy and Sx. Their means are fixed to zero.}
\item{mean_logcov, var_logcov}{Mean and nonnegative variance of logcov, key NCov.}
\item{intercepts, between_residual_variances}{Between item intercepts and nonnegative residual variances, named by item.}
\item{latent_covariance}{Ty WITH Tx, key Ty_WITH_Tx; strictly between -1 and 1 because both latent variances are fixed to 1.}
}
Values in Usage are actual example defaults to adapt to the study. Update named population vectors when changing the item names/counts. No scientific values are inferred from the item names. A scalar broadcasts across its named targets. Log-variance means can be negative; variances cannot. Unspecified covariance settings otherwise follow Mplus defaults.

Identification and scale constraints in BOTH MODEL POPULATION and MODEL:
\preformatted{
[logVSy@0];
[logVSx@0];
[Ty@0];
[Tx@0];
Ty@1;
Tx@1;
NCov BY Sy@1 Sx@1;
}
The first two statements fix the means of log innovation variances to set the within-factor scales, not their heterogeneity. They do not set raw variances to zero or, with nonzero log-variance variance, arithmetic mean variances to one. The Ty/Tx means and variances set between-factor origins and scales. NCov's loadings set the shared component's scale and covariance construction. These are identification choices of this template, not requirements for every DSEM. They cannot be overridden through population_values. Custom models are supplied as modelstring. Population loadings use @ values, whereas MODEL loadings use *. Only the within-factor BY statements include the fixed lag declaration (&1).

Output files are generation.inp, generation.out, rep*.dat, one rep*.rds per successfully imported data.frame, and manifest.csv. No combined RDS is saved. SAVEDATA INFORMATION supplies column order. CLUSTER becomes id; saved TIME is retained, or within-cluster row order becomes time=1,...,TT when TIME is absent. Only id, time and requested item columns are retained. N participants, TT rows per participant, unique id/time cells and finite item values are checked. Failed imports are retained as NULL and generation_error in the manifest with a warning. Missing output or column metadata stops the call and leaves files for inspection. The Monte Carlo summary is not a per-replication analysis output for evaluate_pmd. Pass the returned object to \code{\link{analyze_mplus}} for complete-data analysis, or apply PMD with pmd_batch and pass that result to analyze_mplus. Evaluate those per-dataset analysis results separately.
}
\section{Complete default Mplus input}{
This is the full input for N=10, TT=20, replication=2 and seed=1 with the defaults above. It can be inspected without running R. An identical file is installed at \code{system.file("templates", "default_dsem.inp", package="pmdplan")}. For custom modelstring, copy only ANALYSIS through OUTPUT; the function supplies the MONTECARLO section from its arguments.
\preformatted{
TITLE: Complete data generation;
MONTECARLO:
NAMES ARE y1 y2 y3 x1 x2 x3;
NOBSERVATIONS = 200;
NCSIZES = 1;
CSIZES = 10(20);
NREP = 2;
SEED = 1;
REPSAVE = ALL;
SAVE = rep*.dat;
ANALYSIS:
TYPE = TWOLEVEL RANDOM;
ESTIMATOR = BAYES;
PROCESSORS = 2;
FBITERATIONS = 100;
MODEL POPULATION:
\%WITHIN\%
Sy BY y1@0.8(&1);
Sy BY y2@0.6(&1);
Sy BY y3@0.6(&1);
Sx BY x1@0.8(&1);
Sx BY x2@0.6(&1);
Sx BY x3@0.6(&1);
phi1 | Sy ON Sy&1;
phi2 | Sx ON Sx&1;
phi3 | Sx ON Sy&1;
phi4 | Sy ON Sx&1;
NCov BY Sy@1 Sx@1;
err1 | y1;
err2 | y2;
err3 | y3;
err4 | x1;
err5 | x2;
err6 | x3;
logVSy | Sy;
logVSx | Sx;
logcov | NCov;
\%BETWEEN\%
[phi1@0.2];
[phi2@0.2];
[phi3@0.1];
[phi4@0.1];
[err1@-1.20397280432594];
[err2@-1.20397280432594];
[err3@-1.20397280432594];
[err4@-1.20397280432594];
[err5@-1.20397280432594];
[err6@-1.20397280432594];
[logVSy@0];
[logVSx@0];
[logcov@-2.99573227355399];
phi1@0.01;
phi2@0.01;
phi3@0.01;
phi4@0.01;
err1@0.05;
err2@0.05;
err3@0.05;
err4@0.05;
err5@0.05;
err6@0.05;
logVSy@0.05;
logVSx@0.05;
logcov@0.01;
Ty BY y1@0.7;
Ty BY y2@0.7;
Ty BY y3@0.7;
Tx BY x1@0.7;
Tx BY x2@0.7;
Tx BY x3@0.7;
[y1@0];
[y2@0];
[y3@0];
[x1@0];
[x2@0];
[x3@0];
y1@0.2;
y2@0.2;
y3@0.2;
x1@0.2;
x2@0.2;
x3@0.2;
[Ty@0];
[Tx@0];
Ty@1;
Tx@1;
Ty WITH Tx@0.2;
MODEL:
\%WITHIN\%
Sy BY y1*(&1);
Sy BY y2*(&1);
Sy BY y3*(&1);
Sx BY x1*(&1);
Sx BY x2*(&1);
Sx BY x3*(&1);
phi1 | Sy ON Sy&1;
phi2 | Sx ON Sx&1;
phi3 | Sx ON Sy&1;
phi4 | Sy ON Sx&1;
NCov BY Sy@1 Sx@1;
err1 | y1;
err2 | y2;
err3 | y3;
err4 | x1;
err5 | x2;
err6 | x3;
logVSy | Sy;
logVSx | Sx;
logcov | NCov;
\%BETWEEN\%
[phi1] ;
[phi2] ;
[phi3] ;
[phi4] ;
[err1] ;
[err2] ;
[err3] ;
[err4] ;
[err5] ;
[err6] ;
[logVSy@0];
[logVSx@0];
[logcov];
phi1;
phi2;
phi3;
phi4;
err1;
err2;
err3;
err4;
err5;
err6;
logVSy;
logVSx;
logcov;
Ty BY y1*;
Ty BY y2*;
Ty BY y3*;
Tx BY x1*;
Tx BY x2*;
Tx BY x3*;
[y1];
[y2];
[y3];
[x1];
[x2];
[x3];
y1;
y2;
y3;
x1;
x2;
x3;
[Ty@0];
[Tx@0];
Ty@1;
Tx@1;
Ty WITH Tx;
OUTPUT: TECH8;
}
}
\value{A list with data (one data.frame or NULL per requested replication), manifest (replication, status, dat, rds and error), items, input and output paths, the complete modelstring, population_values, N, TT, replication and path. For run=FALSE, data entries are NULL and manifest status is not_run. Use result$data with pmd_batch, or one result$data[[i]] with pmd_forms/pmd_occasions. Saved RDS files here contain data.frames directly, unlike the pmd_data objects saved by pmd_batch.}
\references{Mplus User's Guide, Chapter 19: \url{https://www.statmodel.com/HTML_UG/chapter19V8.htm}. MplusAutomation runModels: \url{https://michaelhallquist.github.io/MplusAutomation/reference/runModels.html}.}
\seealso{\code{\link{pmd_batch}}, \code{\link{pmd_forms}}, \code{\link{evaluate_pmd}}}
\examples{
# Prepare a simulation using the default model and population values.
# This creates Mplus input, rather than using an empirical dataset.
folder <- tempfile("mplus-generation-")
prepared <- generate_mplus_data(N = 100, TT = 76, replication = 10,
  path = folder, run = FALSE)
prepared$input
unlink(folder, recursive = TRUE)
}
