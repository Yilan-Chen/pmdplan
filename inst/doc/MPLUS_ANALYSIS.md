# Mplus analysis with complete custom scripts

## Default and custom syntax

With `modelstring = NULL`, `analyze_mplus()` generates a default DSEM input using arguments such as `items`, `id`, `time`, `processors` and `biterations`.

For custom analysis, supply complete Mplus input text. The function writes the selected script unchanged to `analysis.inp` in each task directory and uses `run` to determine whether to call Mplus. Supply every required DATA, VARIABLE, ANALYSIS, MODEL, OUTPUT and other section, including correct paths and line breaks. The function does not merge default sections, replace placeholders, modify FILE statements or wrap long lines. A character vector is written with a newline between elements.

## One shared script or one script per task

A single string containing line breaks, or a character vector of lines, represents one shared script. To use different scripts for different datasets, supply a list with exactly one complete script per manifest row:

```r
modelstring <- list(
  rep1_matrix,    # Replication 1, matrix design
  rep1_balanced,  # Replication 1, balanced design
  rep1_complete,  # Replication 1, complete data
  rep2_matrix,    # Replication 2, matrix design
  rep2_balanced,  # Replication 2, balanced design
  rep2_complete  # Replication 2, complete data
)
```

These objects contain input text, not file paths. Use `readLines()` to read scripts saved in files. With 500 replications and three PMD designs, the list requires 1500 scripts, or 2000 when complete-data comparisons are included. Check `nrow(b$manifest)` to determine the required length. Failed entries also occupy positions. List elements match by position, not by name; a one-element list is not recycled. A plain character vector is one shared script, not a collection of task-specific scripts.

## Match scripts to datasets

```r
b <- pmd_batch(existing_data, designs = designs,
  include_complete = TRUE, directory = "pmd_data")
b$manifest[c("condition", "replication", "design", "object")]
```

The batch orders replications first, then designs in the supplied order, followed by the complete-data comparison when requested. Analysis retrieves batch data through `manifest$object`. Follow manifest order even if `b$data` has been rearranged. Separately supplied metadata must maintain the same correspondence.

Keep failed entries in their positions so later scripts remain correctly aligned. Failed analysis tasks retain manifest rows while other tasks continue. Valid complete data can be analyzed even when a PMD design fails.

The objects `existing_data` and `designs` above are user-supplied inputs. The complete example below uses the included `affect` dataset.

## Task directories and data filenames

R data frames, `pmd_data` objects and RDS inputs are exported into separate directories:

```text
custom_analysis/
  fit1_condition1_matrix_rep1/
    data_rep1_matrix.dat
    analysis.inp
  fit2_condition1_balanced_rep1/
    data_rep1_balanced.dat
    analysis.inp
  fit3_condition1_complete_rep1/
    data_rep1_complete.dat
    analysis.inp
```

Labels retain Unicode characters and spaces. Path separators, control characters and characters invalid in Windows filenames are replaced with underscores. Each label is limited to 50 characters, and the fit index prevents directory-name collisions.

DAT names contain the replication identifier and design label, such as `data_rep2_matrix.dat`. Replication identifiers come from metadata and need not start at one. Write the matching filename explicitly in each custom script:

```mplus
DATA:
FILE = "data_rep1_matrix.dat";
```

Existing DAT inputs retain their original paths and names and are not copied. Relative paths resolve from the task directory. The function does not parse custom FILE statements or compare them with `data`; `manifest$dat` records the supplied or exported dataset path.

## Complete example

This example compares a balanced design with complete data. `run = FALSE` prepares files without running Mplus.

```r
library(pmdplan)
data("affect", package = "pmdplan")
items <- c(paste0("x", 1:4), paste0("y", 1:4))
designs <- list(balanced = function(data, seed) {
  pmd_occasions(data, "N_index", "time", pmd_item = items,
    design = "balanced", seed = seed)
})
b <- pmd_batch(list(affect), designs, include_complete = TRUE)
scripts <- lapply(seq_len(nrow(b$manifest)), function(i) c(
  paste0("TITLE: ", b$manifest$design[i], ";"),
  "DATA:",
  paste0('FILE = "data_rep', b$manifest$replication[i], '_', b$manifest$design[i], '.dat";'),
  "VARIABLE:",
  "NAMES = N_index x1 x2 x3 x4 y1 y2 y3 y4 time;",
  "USEVARIABLES = y1-y4;", "CLUSTER = N_index;", "MISSING = ALL(-9);",
  "ANALYSIS: TYPE = TWOLEVEL; ESTIMATOR = BAYES;",
  "PROCESSORS = 2; BITERATIONS = 50000 (2000);",
  "MODEL:", "%WITHIN%", "y1-y4;", "%BETWEEN%", "y1-y4;",
  "OUTPUT: TECH8;"
))
folder <- tempfile("custom-analysis-")
fit <- analyze_mplus(b, modelstring = scripts, missing = -9,
  mc.cores = 1, path = folder, run = FALSE)
fit$manifest
unlink(folder, recursive = TRUE)
```

Each task uses its matching script. Parallel execution uses PSOCK/`parLapply` on Windows and `mclapply` on macOS/Linux. `mc.cores` defaults to 1.

In custom mode, template arguments such as `items`, `id`, `time`, `processors`, `biterations` and `data_names` do not modify or validate the script. `mc.cores`, `path`, `run` and `Mplus_command` control execution.

For R inputs, export includes all numeric columns in their input order, preserving row order. `missing` controls the exported `NA` code and must agree with the script's MISSING statement. For existing DAT inputs, declare missing values directly in the custom script. Planned missing values in R remain numeric-column `NA` values.

The default script derives USEVARIABLES from unique item names, lists all exported numeric columns in NAMES, and uses `id` and `time` for CLUSTER and TINTERVAL. It reads free-format data. Supply a complete custom script to use fixed FORMAT or different USEVARIABLES and MISSING declarations.

## Results and evaluation

The result contains `manifest`, `output`, `metadata`, `items` and `modelstring`. In custom mode, `items` is `NULL` and `modelstring` retains the supplied text or list. Default mode returns its item settings and MODEL text.

`output_created` means only that a file exists; it does not establish successful estimation or convergence. The analysis function uses MplusAutomation's default execution options and does not inspect output contents.

Keep all output paths and corresponding metadata for evaluation. Include `OUTPUT: TECH8;` in Bayesian scripts when PSR is required. Set `evaluate_pmd()`'s `max_iterations` to the fitting limit used in the analysis. Complete data and PMD fits are evaluated under separate design labels.
