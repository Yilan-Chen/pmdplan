# Evaluation workflow and input examples

The manual estimates, population values and posterior samples in this guide are illustrative inputs, not analysis results from `affect`. Supply your own RDS files, Mplus output files and parameter maps where indicated.

## Export an RDS dataset for Mplus

Each RDS saved by `pmd_batch()` contains a `pmd_data` object with data, mask and metadata. Extract the analysis columns and export them with base R:

```r
one <- readRDS("pmd_output/r1_d1.rds")
dat <- one$data[, c("id", "time", "y1", "y2"), drop = FALSE]
write.table(dat, file = "rep1.dat", sep = " ", na = "-9999",
            row.names = FALSE, col.names = FALSE, quote = FALSE)
```

Adapt the paths and column names. Mplus columns should be numeric; explicitly encode any factors or character variables. Choose a missing-value code that does not occur in the data. Column order and missing-value codes must match the Mplus script. The original RDS retains all data and PMD information.

## Conditions and population values

`condition` distinguishes study settings, such as `N60_T20` and `N100_T30`. For one setting, omit it from estimates, metadata and population values; it defaults to `condition1`. A setting can include multiple designs and replications. Coverage and power are calculated across repeated fitted datasets.

A `population_value` table without `condition` applies to all settings. Include `condition` to specify different targets or values by setting. One `evaluate_pmd()` call uses one common model and PSR cutoff.

```r
population_value <- data.frame(
  parameter = c("beta", "intercept"),
  value = c(0.2, 0)
)
```

`value` is the known or assumed population parameter for the replicated datasets. It determines bias, relative bias, RMSE, coverage, power and Type I error. A single empirical estimate does not automatically establish a population value. Target names must match the manual table, posterior columns or Mplus map.

## Manual input and failed fits

Each row represents one parameter in one replication. Required columns are `design`, `replication`, `parameter`, `estimate`, `sd`, `lower`, `upper` and `max_psr`; `condition` is optional. Design labels identify completed analyses; evaluation does not reapply missingness.

Keep at least one target-parameter row for a failed replication, with missing estimates and diagnostics. Omitting that replication would omit it from the convergence-rate denominator.

```r
library(pmdplan)
population_value <- data.frame(
  parameter = c("beta", "intercept"), value = c(.2, 0)
)
estimates <- data.frame(
  design = "anchor",
  replication = rep(1:3, each = 2),
  parameter = rep(c("beta", "intercept"), 3),
  estimate = c(.19, .01, .22, -.01, .50, .20),
  sd = rep(.05, 6),
  lower = c(.09, -.09, .12, -.11, .40, .10),
  upper = c(.29, .11, .32, .09, .60, .30),
  max_psr = c(1.01, NA_real_, 1.03, NA_real_, 1.12, NA_real_)
)
# Retain the failed fourth fit in the convergence-rate denominator.
estimates <- rbind(estimates, data.frame(
  design = "anchor", replication = 4, parameter = "beta",
  estimate = NA_real_, sd = NA_real_, lower = NA_real_,
  upper = NA_real_, max_psr = NA_real_
))
result <- evaluate_pmd(
  estimates, population_value, source = "manual", cutoff = 1.05,
  exclude_rbias = "intercept", max_abs_relative_bias = .1
)
result
attr(result, "replications")
attr(result, "design_summary")
```

Supply one model-wide maximum PSR per fit, either once with `NA` on other parameter rows or repeated identically. Conflicting nonmissing values are an error. The package compares that value directly with `cutoff`; it does not derive PSR from point estimates or maximize over replications. Equality, entirely missing values and positive infinity fail the check; zero and negative PSR are invalid inputs. Two of the four fits above converge.

## Relative bias

By default, relative bias is calculated for all targets with nonzero population values, using their actual values. `exclude_rbias` names targets whose relative bias and corresponding screening should be skipped. Their bias, RMSE, coverage, power and Type I error remain available.

Relative bias is undefined for an exactly zero population value. When relative-bias screening is enabled, explicitly exclude zero-valued targets; otherwise their undefined relative bias fails that check. `relative_bias_defined` indicates a nonzero population value, and `relative_bias_excluded` records an explicit exclusion.

## Metadata for MCMC and Mplus inputs

Supply one metadata row per input in the same order:

```r
metadata <- data.frame(
  design = c("anchor", "anchor", "matrix", "matrix"),
  replication = c(1, 2, 1, 2)
)
# Corresponding MCMC inputs:
# list(anchor_draws1, anchor_draws2, matrix_draws1, matrix_draws2)
# Corresponding Mplus inputs:
# c("anchor_1.out", "anchor_2.out", "matrix_1.out", "matrix_2.out")
```

Retain failed MCMC inputs as `NULL` list elements and unreadable Mplus paths in the input vector. Import failures remain in the convergence-rate denominator. Supply `n_factors` as a common function argument, not a metadata column.

## PSR cutoffs

The default is strictly less than 1.05 for `n_factors = 1` and strictly less than 1.10 for other factor counts. An explicit `cutoff` overrides the default and can be used without `n_factors`. At least one of these arguments is required. A construct represented at both within and between levels counts as one factor.

## Map Mplus output to target parameters

A map connects target names with exact rows in the parsed output:

```r
map <- data.frame(parameter = "beta", paramHeader = "Y.ON", param = "X")
```

All map columns other than `parameter` participate in matching. Add `BetweenWithin` when needed to distinguish levels, or an existing group identifier for multigroup output:

```r
map <- data.frame(
  parameter = "beta", paramHeader = "SY.ON",
  param = "W", BetweenWithin = "Between"
)
# After preparing the output files:
# result <- evaluate_pmd(
#   c("anchor_1.out", "anchor_2.out"),
#   data.frame(parameter = "beta", value = .12),
#   source = "mplus",
#   metadata = data.frame(design = "anchor", replication = 1:2),
#   map = map, cutoff = 1.05, max_iterations = 80000
# )
```

Use `obtain_map()` to prepare a template. Name the parameters of interest and retain the parsed row identifiers. Do not add notes or population values as identifier columns. Each selected row must match exactly one output row. Results follow map order, while convergence uses the complete fit's TECH8 diagnostics.

The reader requires numeric `est`, `posterior_sd`, `lower_2.5ci` and `upper_2.5ci` columns from the `unstandardized` table. These supply point estimates, posterior SDs and interval endpoints. Missing required columns cause an import error. `evaluate_pmd()` records the failed replication as `import_error` and retains it in the denominator. Other output formats can be converted to manual input.

Mplus convergence requires all of the following:

- The final TECH8 `psr` is finite and strictly below `cutoff`.
- `errors_flag` is false.
- The final TECH8 `iteration` is finite and strictly below `max_iterations` (default 50000).

When `length(out$errors) > 1`, the error flag is false only when PSR passes and the error text does not contain `THE MODEL ESTIMATION DID NOT TERMINATE NORMALLY`. With a list length of at most one, the flag is false. Length is measured before flattening the error list. The check does not use `out$converged`. Missing, empty or nonfinite diagnostics cannot establish convergence.

`max_iterations` checks existing output; it does not set or run Mplus. Match it to the fitting limit used in your analysis. Inspect `attr(result, "diagnostics")[[i]]` for `last_iteration`, `max_iterations`, `iteration_limit_reached` and `errors_flag`. Each output file should represent one fit.

## Posterior summaries and intervals

For MCMC input, `prob` controls the equal-tail credible interval: .95 uses the 2.5% and 97.5% quantiles; .90 uses the 5% and 95% quantiles. It does not alter manual or Mplus intervals or screening bounds. Changes in interval width can affect coverage, power and Type I error.

A fit's point estimate is the median of pooled retained chain samples; its posterior SD is the standard deviation of those samples. PSR uses the unsplit variance-ratio formula and chain means. Across replications, `mean_estimate` averages the fit-specific point estimates, hence the posterior medians for MCMC input.

## Convergence records and metric denominators

Inspect `attr(result, "replications")$converged` for per-fit convergence. Parameter summaries are in `attr(result, "estimates")`; their corresponding convergence records are matched by `condition`, `design` and `replication`, independently of row order. The evaluator creates these records internally. Raw diagnostic results remain available in the `diagnostics` attribute.

Convergence rate includes all supplied replications, including failed imports. Other metrics use converged replications with finite point estimates. `mean_sd` also requires a finite SD; interval metrics require both finite endpoints. `n_valid`, `n_sd` and `n_interval` report the respective usable counts. Empirical SD requires at least two usable estimates. Unavailable metrics are `NA`.

Power applies to nonzero population values, and `typeI_error` to exactly zero values. An interval excludes zero only if `lower > 0` or `upper < 0`; an endpoint at zero does not qualify.

## Screening and results

Default bounds are absolute relative bias at most .10, coverage in [.91, .98], power at least .80 and Type I error in [.025, .075]. Customize them with `max_abs_relative_bias`, `min_coverage`, `max_coverage`, `min_power`, `min_typeI_error` and `max_typeI_error`. These bounds accept `NULL` to disable a check or one side of it. In contrast, `cutoff = NULL` selects the factor-based PSR default, and the Mplus iteration limit cannot be disabled with `NULL`.

Convergence rate, mean estimate, bias, RMSE, empirical SD and mean SD are reported without screening cutoffs. ESS, metric MCSE, valid rate and average interval width are not calculated.

Printing the result lists designs passing all applicable enabled criteria. Inspect `eligible` and `reason`, or the design summary:

```r
summary <- attr(result, "design_summary")
summary[summary$eligible, c("condition", "design"), drop = FALSE]
```

Eligibility applies to the specified setting, target parameters and bounds. There is no minimum convergence-rate criterion, so inspect that rate as well. Targets without usable converged estimates cannot pass. `screen_designs()` can screen selected targets or different bounds and returns a separate table.

## Installation and help

```r
install.packages("remotes")
remotes::install_github("Yilan-Chen/pmdplan")
library(pmdplan)
?evaluate_pmd
?mcmc_diagnostics
?read_mplus_estimates
?screen_designs
```

Parallel execution uses `parLapply` on Windows and `mclapply` on macOS/Linux; `mc.cores` defaults to 1. `pmd_batch()` saves individual RDS files and `manifest.csv`, preserving columns outside the selected items.
