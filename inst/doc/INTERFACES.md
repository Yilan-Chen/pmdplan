# Input and output interfaces

## Existing data

Each data row represents one participant at one measurement occasion. Set id to the participant identifier column name and time to the measurement time column name, for example id="N_index" and time="time". Participant identifiers may be numeric, character, or factor values. The time column may be numeric, character, factor, Date, or POSIXct. Item columns may be numeric, character, logical or factor variables. Missing ID/time values and duplicate participant-time pairs are not allowed. PMD preserves existing missing responses. Participants may have different measurement times and record counts. pmd_forms uses design="matrix", "anchor" or "random"; pmd_occasions uses design="balanced", "consistent" or "truncated". Select PMD variables by column name with items in pmd_forms and pmd_item in pmd_occasions. Anchor designs require anchors or cfa_type; supplied anchors disable CFA. Automatic construction randomly distributes each factor's items as evenly as possible, assigning extra items to subsets containing fewer items. In anchor designs, anchors form one subset and the remaining items are distributed among the other subsets.

pmd_batch accepts a list of existing data.frames, named PMD functions(data,seed), and metadata with condition/replication. No generation or fitting callbacks. It returns data objects, a manifest, burdens, metadata and seeds. Optional disk output uses a new/empty directory and writes one RDS per successful combination plus manifest.csv, without a combined batch RDS. Each RDS holds pmd_data, including data and mask. The in-memory return still holds all objects. Folder creation warnings are visible.

For external text data, read each RDS, extract its data component, select the required numeric columns and call utils::write.table. Use column names from your own data and preserve their order in the Mplus input. Data export is handled by the user rather than a package function.

## Evaluation inputs

See ?evaluate_pmd for runnable schemas and examples. source is manual, mcmc or mplus. condition is optional (condition1); design and parameter are user labels, and replication is a positive integer. One model uses one n_factors/cutoff.

population_value has parameter/value, with optional condition. Without condition, the same values apply to all conditions. With condition, each condition may have its own target set and values. All values are population parameters underlying the repeated datasets.

Manual estimates has design, replication, parameter, estimate, sd, lower, upper, max_psr. Supply a whole-fit max_psr once per replication (other parameter rows may have NA), or repeat the identical number. It is directly compared with cutoff. Keep an NA placeholder with a target name for failed replications. No runs input.

MCMC estimates is a list of mcmc.list objects, one per replication; keep NULL for failed fits. metadata has design/replication, one row per list element in order. Pooled posterior medians are the point estimates. prob defines the credible-interval mass; burnin discards additional stored rows. All supplied sampled parameters, including nontargets, govern maximum unsplit PSR.

Mplus estimates is a vector of existing per-fit .out paths. metadata has the same schema and order rule as MCMC. Before evaluation, call `obtain_map("rep1.out", path="my_study")`. Open `my_study/map.csv` and fill the blank `parameter` column only for desired parameters. Leave unwanted rows blank; they are ignored automatically. Keep the output identifiers unchanged, including `BetweenWithin` for two-level models. Read the edited CSV with `utils::read.csv("my_study/map.csv", colClasses="character", check.names=FALSE)`. Pass that table to `evaluate_pmd(..., source="mplus", map=map)` and use the chosen names in `population_value`. map requires parameter, paramHeader and param. All map columns except parameter are automatically matched, including BetweenWithin or actual group identifiers. Do not put notes or reference values in map. Only parameters of interest need to be listed, including all targets in population_value. The model-level TECH8 diagnostics do not depend on this subset. The reader always uses unstandardized with est, posterior_sd, lower_2.5ci and upper_2.5ci. All four numeric columns are required; missing columns cause an import error. There is no fallback to se or configurable table/column selection. Use manual input for different output formats.

## Evaluation output

A pmd_evaluation data.frame includes all metrics, plus eligible and reason. Printing lists the PMD designs meeting all applicable active criteria for the supplied scenario and targets. Attributes:

- design_summary: condition/design/eligible/reason, one row per design.
- screening_cutoffs: the exact cutoff values used to screen.
- replications: each attempt's source, status, converged, max_psr, cutoff,
  n_factors and error. Status is ok, nonconverged or import_error.
- estimates: standardized individual results for population_value targets, without
  a converged column; convergence belongs to the replications table.
- diagnostics: one table per attempt; NULL on import failure.
- source: the selected route.

Metric calculation matches parameter rows to the authoritative replications record by condition/design/replication, not by row position. Original diagnostic outputs remain available separately.

All attempts count toward convergence rate; other metrics use converged finite point estimates and, where needed, finite SDs or bounds. NULL/missing-file imports remain as failures and issue a warning. Inspect attr(result,"replications"). exclude_rbias omits named parameters from relative-bias calculation and screening, without changing other metrics. Exactly zero values have undefined relative bias.

## Parallel processing

pmd_batch and evaluate_pmd use parallel::parLapply with PSOCK workers on Windows and parallel::mclapply on macOS/Linux. mc.cores=1 is the default everywhere; positive integers above one enable multiple workers. Explicit task seeds and inherited RNG kind make PMD allocation reproducible across core counts and backends. Windows workers receive current library paths and ordinary referenced objects/helper functions used by design functions. Clusters close on return or error. Evaluation performs deterministic summaries/importing and does not launch model processes. Per-task errors are retained as failed replications; cluster startup or communication failures stop processing. Optional saving is done by the parent process.

## Mplus convergence inputs and diagnostics

A nonempty tech8$psr is the standard table with numeric psr and iteration columns. Both are read directly, with no alternative-name or duplicate-column handling.

max_iterations is a positive integer limit, default 50000, shared by all Mplus replications in a call. Supply it to evaluate_pmd, read_mplus_estimates or mplus_convergence. A final TECH8 iteration equal to the limit fails. The final PSR must also be below cutoff and the configured error-list rule must give FALSE. The rule preserves length(out$errors)>1 before unlisting messages; see the Rd page for mplus_convergence. There is no alternative convergence selector.

attr(result,"diagnostics")[[i]] contains last_iteration, max_iterations, iteration_limit_reached and errors_flag for Mplus replication i. Missing/nonfinite iteration cannot establish convergence. This limit does not configure Mplus and does not apply to manual or MCMC inputs.

## Batch analysis with Mplus

`analyze_mplus()` prepares a default DSEM from `items`, `id`, `time`, `processors` and `biterations`. This example uses the included affect data and does not run Mplus:

```r
data("affect", package = "pmdplan")
items <- list(Sy = paste0("y", 1:4), Sx = paste0("x", 1:4),
              Ty = paste0("y", 1:4), Tx = paste0("x", 1:4))
folder <- tempfile("mplus-analysis-")
# Prepare input files without running Mplus.
prepared <- analyze_mplus(affect, items = items,
  id = "N_index", time = "time", processors = 2, biterations = "(1000)",
  path = folder, run = FALSE)
prepared$manifest
unlink(folder, recursive = TRUE)
```

For custom analyses, provide complete input syntax in `modelstring`, including DATA, VARIABLE, ANALYSIS, MODEL and OUTPUT. The function writes each script unchanged. A character vector supplies one script; a list supplies one script per dataset in manifest order. Set `run = TRUE` to run Mplus. The executable must be installed separately.

For 500 replications and three PMD designs, a custom script list has 1500 entries; with `include_complete = TRUE`, it has 2000. Each task exports R data to `data_repN_DESIGN.dat`; custom scripts must explicitly reference the corresponding filename. For existing DAT input, scripts must use the actual supplied paths. Default syntax uses the unique names in `items` for USEVARIABLES and exports all numeric columns. Custom syntax controls its own variable declarations, model and analysis settings.

The returned manifest records each task. Output-file existence does not establish convergence. Use `evaluate_pmd()` with matching output paths and metadata, an edited map and the population values from your simulation. For Bayesian evaluation, include OUTPUT: TECH8 and set max_iterations to the actual fitting limit. A complete custom-script example using `affect` is provided in `inst/doc/MPLUS_ANALYSIS.md`.

## Empirical affect data

The only included empirical dataset is `affect`. Mplus output files and edited maps must be supplied by the user. Manual estimate tables and posterior chains in examples are illustrative objects constructed in the example itself.

`affect` contains the prepared Rowland and Wenzel (2020) baseline: 9,500 rows from 125 participants, with 76 retained occasions per participant. Eight emotion items use the original 0--100 scale; the included subset has no missing values. The column order is N_index, x1--x4, y1--y4, time. Positive affect items x1--x4 are happy, excited, relaxed and satisfied; negative affect items y1--y4 are angry, anxious, depressed and sad. Use `id="N_index"` and `time="time"` with the PMD functions. Time indexes retained measurements, not elapsed time; occasions with all eight items missing were removed before the first 76 were selected.

```r
data("affect", package = "pmdplan")
head(affect)
help("affect", package = "pmdplan")
```

The data-specific help follows the Description, Usage and Format structure of standard R dataset documentation, with variable definitions, preparation notes, source and study reference. See `inst/examples/08_affect.R` for item and occasion PMD examples. Data source: https://openesmdata.org/datasets/0006_rowland/. The dataset is distributed under CC BY-NC 4.0 as reported by openESM, separately from the software's GPL-3 license; see LICENSE and the dataset help.
