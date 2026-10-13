# pmdplan

Version **0.1.0**. Apply planned missingness to intensive longitudinal data, and evaluate planned missingness designs.

Install the development version from GitHub:

```r
install.packages("remotes")
remotes::install_github("Yilan-Chen/pmdplan")
```

Alternatively, install a downloaded source archive:

```r
install.packages("/path/to/pmdplan_0.1.0.tar.gz", repos=NULL, type="source")
library(pmdplan)
help("pmdplan_getting_started")
```

## Empirical affect data

`affect` is the only empirical dataset included in pmdplan. Observation-data examples use its eight affect items. Schedule examples use these same item names without requiring response data. Small estimate tables and posterior chains are explicitly illustrative inputs. Mplus output files and edited parameter maps must be supplied by the user.

`affect` contains the prepared Rowland and Wenzel (2020) baseline: 9,500 rows from 125 participants, with 76 retained occasions per participant. Eight emotion items use the original 0--100 scale; the included subset has no missing values. The column order is N_index, x1--x4, y1--y4, time. Positive affect items x1--x4 are happy, excited, relaxed and satisfied; negative affect items y1--y4 are angry, anxious, depressed and sad. Use `id="N_index"` and `time="time"` with the PMD functions. Time indexes retained measurements, not elapsed time; occasions with all eight items missing were removed before the first 76 were selected.

```r
data("affect", package = "pmdplan")
head(affect)
help("affect", package = "pmdplan")
```

The data-specific help follows the Description, Usage and Format structure of standard R dataset documentation, with variable definitions, preparation notes, source and study reference. See `inst/examples/08_affect.R` for item and occasion PMD examples. Data source: https://openesmdata.org/datasets/0006_rowland/. The dataset is distributed under CC BY-NC 4.0 as reported by openESM, separately from the software's GPL-3 license; see LICENSE and the dataset help.

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

## Generate complete data with Mplus

`generate_mplus_data()` generates all requested replications in one Mplus Monte Carlo run. N is the number of participants and TT the number of rows per participant. The function provides the editable default inputs below. Sy/Sx define within-level item membership; Ty/Tx define between-level membership of the same observed columns. Thus the example generates six observed variables, not twelve. There is no minimum-three-items check; Mplus assesses model feasibility.

```r
items <- list(
  Sy = c("y1", "y2", "y3"),
  Sx = c("x1", "x2", "x3"),
  Ty = c("y1", "y2", "y3"),
  Tx = c("x1", "x2", "x3")
)
population_values <- list(
  within_loadings = c(y1=.8, y2=.6, y3=.6, x1=.8, x2=.6, x3=.6),
  between_loadings = .7,
  phi_mean = c(phi1=.2, phi2=.2, phi3=.1, phi4=.1),
  phi_variance = .01,
  mean_logerror = log(.3), var_logerror = .05,
  var_logre = .05,
  mean_logcov = log(.05), var_logcov = .01,
  intercepts = 0, between_residual_variances = .2,
  latent_covariance = .2
)
generated <- generate_mplus_data(items, N=100, TT=50, replication=100,
  population_values=population_values, path="complete_data", seed=123)
```

These are actual function defaults and are examples to adapt to the study. If changing item names or counts, update both the within/between item lists and any item-named population vectors. Each population field can instead be one unnamed number shared across its targets. A supplied list must contain all 12 editable fields above. phi1/phi2 are Sy/Sx autoregressive coefficients; phi3 is Sx on lagged Sy and phi4 is Sy on lagged Sx. Log-variance means and variances use the log scale, not the raw variance scale.

### Fixed identification and scale constraints

The following are fixed in **both MODEL POPULATION and MODEL** in this template:

| Statement | Role |
|---|---|
| `[logVSy@0]; [logVSx@0];` | Fix the means of log innovation variances at zero to set the within-factor scales; their variances remain adjustable |
| `[Ty@0]; [Tx@0];` | Fix between-factor means to zero to set their origins |
| `Ty@1; Tx@1;` | Fix between-factor variances to one to set their scales |
| `NCov BY Sy@1 Sx@1;` | Fix the shared component's two loadings to one, setting its scale and covariance construction |

These choices identify and scale this particular template; other models can use other identification conventions. A mean log variance of zero does not set the raw variance to zero, and does not fix its arithmetic mean at one when log-variance heterogeneity is present.

The default ANALYSIS settings are fixed as follows:

```mplus
ANALYSIS:
TYPE = TWOLEVEL RANDOM;
ESTIMATOR = BAYES;
PROCESSORS = 2;
FBITERATIONS = 100;
```

For different settings or models, provide `modelstring` with ANALYSIS, MODEL POPULATION and MODEL sections (optionally OUTPUT). Do not supply population_values with custom syntax. The function supplies MONTECARLO sample sizes, variable names, seed and save settings. Population measurement statements use explicit @ values; within statements include (&1), while between statements do not. MODEL measurement statements explicitly use * for free loadings.

`run=FALSE` only writes the syntax and manifest; `run=TRUE` (default) calls the installed Mplus executable via MplusAutomation. The output directory must be new or empty; directory creation retains showWarnings=TRUE. Each replication has DAT and RDS files, plus a manifest. Returned `$data` is a list of complete data.frames with id, time and items, usable by pmd_batch. Here an RDS holds a data.frame directly. Data-generation success does not establish analysis convergence; the 100-iteration embedded analysis is not a substitute for subsequent PMD fitting and per-replication evaluation.

### Complete default input, ready to inspect

Below is the entire input for N=10, TT=20, replication=2, seed=1 and the defaults above. No function call is needed to see it. The identical file is included as `inst/templates/default_dsem.inp` in the source package (installed location: `system.file("templates", "default_dsem.inp", package="pmdplan")`). For custom modelstring, copy the ANALYSIS-through-OUTPUT sections; MONTECARLO is generated by the function from your N, TT, replication and items arguments.

```mplus
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
%WITHIN%
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
%BETWEEN%
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
%WITHIN%
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
%BETWEEN%
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
```

## Choose a design

| Function and argument | Allowed value | Meaning |
|---|---|---|
| pmd_forms: design | "anchor" | One complete subset stays observed in every form; remaining subsets rotate |
| pmd_forms: design | "matrix" (default) | Rotate generated or supplied forms across measurement occasions |
| pmd_forms: design | "random" | Select a generated or supplied form independently at each occasion |
| pmd_forms: cfa_type | NULL (default), "twolevel", "singlelevel" | No CFA, two-level CFA using within-level loadings, or single-level CFA |
| pmd_occasions: design | "balanced" (default) | Distribute participants evenly among Phase II measurement patterns |
| pmd_occasions: design | "consistent" | Use the same Phase II measurement pattern for everyone |
| pmd_occasions: design | "truncated" | Retain the initial consecutive measurements only |

Supply one row per participant and measurement occasion. `items` in `pmd_forms()` and `pmd_item` in `pmd_occasions()` specify variable names, for example `c("x1", "y1")`. The selected columns may be numeric, character, logical, or factor. Set `id` to the participant identifier column name and `time` to the measurement time column name, for example `id = "N_index"` and `time = "time"`. Participant identifiers may be numeric, character, or factor values. The time column may be numeric, character, factor, Date, or POSIXct. Neither column can contain missing values. Allocation follows each participant's time order; character labels sort alphabetically and factors follow their levels. Use an ordered factor when needed. Other columns are retained unchanged.

For `pmd_forms()`, there is no `mode` argument. Supply subsets explicitly or provide `factors` and `n_subsets` to construct them. `factors` is a named list of item vectors, such as `list(Y = c("y1", "y2", "y3", "y4"), X = c("x1", "x2", "x3", "x4"))`. Automatic construction randomly distributes each factor's items so that its counts across subsets differ by at most one. Extra items go to subsets containing fewer items; for example, five items divided among three subsets give counts of 2, 2 and 1. For anchor designs, the anchor items form one subset and the remaining items are allocated among the others. With two subsets in this example, each receives two Y items and two X items. Supplied subsets may have unequal sizes or shared items.

`subsets_per_form` has the same meaning as in `pmd_schedule()`: the number of subsets combined in a form. It is required when `forms` is omitted and ignored when `forms` is supplied. With four subsets and subsets_per_form = 3, matrix/random use ABC, ABD, ACD, BCD, while anchor A uses ABC, ABD, ACD. When `forms` is supplied, only these combinations are used and their sizes may differ, for example `forms = list(c("A", "B"), c("A", "C", "D"))`. Shared anchor items can instead be included in every subset with design = "matrix".

Anchor/matrix designs balance participants across cyclic starting phases, with group sizes differing by at most one. Sixty participants and three forms give 20 participants per phase. Rotation follows each participant's own time-sorted row positions. Different starting times, gaps and record counts are allowed. Missing rows are not counted as turns; existing NA-response rows are. Shorter records end without reallocating others. Balance at shared calendar times or after shorter records end is not promised. Random allocation is independent and has no forced rotation.

For `design = "anchor"`, supply `anchors` or select CFA with `cfa_type = "twolevel"` or `"singlelevel"`. Manual anchors take priority: if anchors are supplied, cfa_type is ignored and no CFA is fitted. With supplied subsets, anchors must equal one complete subset; the function identifies that subset automatically. With generated subsets, anchors form the first subset. There is no anchor_subset argument. For CFA selection, supply factors and n_subsets and omit subsets and anchors. The anchor count for each factor is ceiling(number of items / n_subsets). Enough non-anchor items must remain for the other subsets. Two-level CFA ranks absolute standardized within-level loadings, while single-level CFA uses single-level loadings; ties follow item order in factors. On fitting or loading-extraction failure, the same anchor counts are selected at random within factors, and a warning lists the selected items. Reuse specification$subsets and specification$anchors to apply the anchor design to other data.

For `pmd_occasions()`, `first_prop` (default 0.5) allocates `floor(TT * first_prop)` time points to consecutive measurement in Phase I. In balanced and consistent designs, `interval` is the number of unmeasured occasions between measurements in Phase II: 0 measures every occasion, 1 every second, and 2 every third. Balanced allocation divides participants among `interval + 1` patterns, with group sizes differing by at most one. Consistent allocation uses the same pattern for everyone. Truncated designs end measurement after Phase I; do not supply interval. Unequal record lengths or incomplete patterns can produce different measured counts, reported in `subject_schedule`.

To compare designs with equal measurement counts, set truncated first_prop to the intended retained proportion. With 76 occasions, consistent first_prop=0.5 and interval=1 retains 38 + 19 = 57 measurements; truncated first_prop=0.75 also retains 57. The default first_prop=0.5 does not give equal counts across these designs. No automatic matching is performed. Before fitting models for an equal-burden comparison, check `subject_schedule$n_observed` for each participant and `burden$planned_missing_prop` in the `pmd_batch()` result, using the same PMD items across designs. `evaluate_pmd()` evaluates fitted results and does not check these quantities. Passing its criteria does not establish equal measurement burden across designs.

```r
data("affect", package = "pmdplan")
items <- c(paste0("x", 1:4), paste0("y", 1:4))

# Compare two designs retaining 57 of 76 occasions per participant.
consistent <- pmd_occasions(affect, "N_index", "time", pmd_item = items,
  design = "consistent", first_prop = 0.5, interval = 1)
truncated <- pmd_occasions(affect, "N_index", "time", pmd_item = items,
  design = "truncated", first_prop = 0.75)
head(consistent$subject_schedule)
head(truncated$subject_schedule)
```

`design` selects the algorithm in `pmd_forms()` and `pmd_occasions()`. Only `apply_pmd()` uses this argument as a metadata label. Both wave-level interfaces accept `"truncated"`; the earlier spelling `"truncate"` remains a recognized abbreviation.

For multiform designs cite: Chen, Y., & Liu, H. (2026). Planned missingness in intensive longitudinal studies: Extensions and comparisons of multiform designs. *Behavior Research Methods, 58*, Article 215. https://doi.org/10.3758/s13428-026-03035-8

## Generate a PMD measurement schedule

Use `pmd_schedule()` with `N`, `TT`, `items`, and either `item_design` or `wave_design` to prepare a plan before collecting responses. No dataset is required. Specify `design` inside the chosen list. `items` lists every item in the schedule; `pmd_items` selects the items to which planned missingness applies and defaults to `items`. Other items are scheduled at every occasion. `TT` is either a common occasion count or a vector of `N` counts.

For item-level planned missingness, set `item_design$design` to `"matrix"` or `"random"`. `subsets` is required and must together cover exactly `pmd_items`. Subsets may share items: include an anchor item in every subset to keep it in every form. There is no separate anchor design or anchor-selection step in this schedule interface.

Within `item_design`, supply `forms` as a list containing the subset names for each form, for example `list(c("A", "B"), c("A", "C"))`, or `subsets_per_form` to specify how many subsets each form contains. Explicit forms may contain different numbers of subsets and need not exhaust all combinations. When forms are supplied, they determine the combinations; subsets_per_form is used only when forms are omitted. Without explicit forms, matrix uses all combinations of the chosen size, and random independently draws such a combination at each occasion. Matrix assigns participants as evenly as possible to starting forms and rotates through forms in a randomly ordered cycle; random selects forms with equal probability. Set `seed` to reproduce an arrangement. To limit memory use, automatic matrix construction stops above 10000 combinations. In this case, supply `forms` listing the subset combinations to use.

For wave-level planned missingness, set `wave_design$design` to `"balanced"`, `"consistent"`, or `"truncated"`. `first_prop` (default 0.5) specifies the proportion of occasions allocated to the initial period of consecutive measurement; its length is `floor(TT * first_prop)` for each participant. For balanced and consistent designs, `interval` (default 1) sets the subsequent spacing: 1 measures every second occasion, 2 every third. Balanced designs divide participants as evenly as possible among `interval + 1` groups with different measurement phases; group sizes differ by at most one. Consistent designs use the same phase for everyone. Truncation ends measurement of the PMD items immediately after the initial period and requires only `first_prop`; for example, TT = 76 and first_prop = 0.5 retain the first 38 occasions. Group sizes and missingness follow these settings; no group_prop or missing_prop argument is used. Items outside `pmd_items` remain measured at every occasion.

For background on measurement-missing designs, see Liu, Y., Luo, X., and Liu, H. (2026), *Planned Measurement-Missing Designs in Intensive Longitudinal Studies: How Well Do They Recover Power and Parameter Estimates?*, *Structural Equation Modeling: A Multidisciplinary Journal*, 33(4), 531–541. https://doi.org/10.1080/10705511.2026.2625171.

The returned data frame has one row per participant and occasion. Its columns are `id`, `time`, and the names in `items`, in that order. Each item column contains TRUE for scheduled measurement and FALSE for planned omission. There are no separate `item` or `planned_observed` columns.

```r
# Use the eight item names in affect; response data are not needed.
items <- c(paste0("x", 1:4), paste0("y", 1:4))
pmd_items <- c(paste0("x", 1:3), paste0("y", 1:3))
item_schedule <- pmd_schedule(
  N = 60, TT = 76, items = items, pmd_items = pmd_items,
  item_design = list(
    design = "matrix",
    subsets = list(A = c("x1", "y1"), B = c("x2", "y2"), C = c("x3", "y3")),
    subsets_per_form = 2
  )
)
head(item_schedule) # x4 and y4 are measured at every occasion.

wave_schedule <- pmd_schedule(
  N = 60, TT = 76, items = items,
  wave_design = list(design = "balanced", first_prop = 0.5, interval = 1)
)
head(wave_schedule)
```

For an existing PMD result, `pmd_schedule(result)` extracts its mask as a schedule and retains the participant IDs, time values, and row order. To include more items from the same data, use `pmd_schedule(result, items = items)`; the vector must include every PMD item. Additional items are always TRUE. These indicators describe planned measurement regardless of existing missing responses. No new design settings are accepted with `x`. See `help("pmd_schedule")` for all list entries and examples.

## Obtain a map before evaluating Mplus results

Mplus output files are not included in pmdplan. For `evaluate_pmd(source="mplus")`, first prepare a map using one of your own complete per-replication outputs. Choose a directory; the filename is always `map.csv`:

```r
obtain_map("anchor_1.out", path = "my_study")
```

Open `my_study/map.csv`. It contains a blank `parameter` column followed by `paramHeader`, `param` and, for two-level output, `BetweenWithin`. Enter your own unique names **only on rows you want to evaluate**, for example `beta`. Leave other rows blank; there is no need to delete them. Save the edited CSV. No names are constructed by joining identifiers with colons.

Keep all identifier columns unchanged. `BetweenWithin` is used automatically when supplied and distinguishes the Within and Between levels. The three base columns are required for every map; the level column must also be retained for two-level mappings. This helper does not generate group or latent class mappings.

```r
map <- utils::read.csv("my_study/map.csv", colClasses = "character",
  check.names = FALSE)
# Use exactly the custom names you entered in the CSV.
population_value <- data.frame(parameter = "beta", value = .12)
metadata <- data.frame(design = "anchor", replication = 1:2)
result <- evaluate_pmd(c("anchor_1.out", "anchor_2.out"), population_value,
  source = "mplus", metadata = metadata, map = map, cutoff = 1.05)
```

Blank, whitespace-only or NA parameter names are ignored during reading. At least one row must be named, and selected names must be unique. Leading/trailing whitespace is removed. Keep population values in `population_value`, not in map; every map column except `parameter` participates in exact matching. `obtain_map()` also returns the template as a data.frame for editing in R. It creates missing directories with `showWarnings=TRUE` and overwrites an existing `map.csv`, so generate the template before filling in names. Reuse the edited map across replications of the same model. This preparation requires no PSR cutoff and does not infer population values. Manual and MCMC input do not use map. See `help("obtain_map")` for an example using your own output file.

## Existing replication batches

Use pmd_batch(data, designs, metadata, mc.cores=1) with a list of existing data.frames and named functions(data, seed) returning pmd_data. metadata has condition and replication. A single supplied dataset is shared across its candidate designs. The output includes PMD objects, missingness metadata and a manifest mapping condition/replication/design to each object or saved file. A NULL or invalid replication is retained as a failed manifest entry.

An optional new/empty directory saves one RDS per successful replication/design combination and manifest.csv. It does not write a combined pmd_batch.rds; the returned in-memory list still contains all results. Read a single file with readRDS(path)$data, or reload successful files listed in manifest.csv. NULL returns results in memory without writing files. See ?pmd_batch for matrix-item and balanced-occasion examples of the designs function list. All package directory creation uses showWarnings=TRUE and checks that the directory exists. Analyze the PMD datasets in your own software.

For a `.dat` file, use base R to export the data stored in an individual RDS:

```r
# Requires an RDS saved by your own pmd_batch() call.
one <- readRDS("pmd_output/r1_d1.rds")
# Select the numeric columns needed for the analysis, in the desired order.
dat <- one$data[, c("id", "time", "y1", "y2"), drop=FALSE]
utils::write.table(dat, file="rep1.dat", sep=" ", na="-9999",
  row.names=FALSE, col.names=FALSE, quote=FALSE)
```

Replace the path and column names with those for your study. For Mplus, recode any needed character/factor variables explicitly, choose a missing code absent from observed values, and use the same column order and missing code in the model input. The RDS keeps the full PMD object; the text file contains only the selected data. There is no separate data-export function in pmdplan.

## Evaluate one applied scenario

`evaluate_pmd()` accepts existing results and immediately identifies which tested PMD designs satisfy all active criteria. A single scenario can omit `condition`. Use `population_value=data.frame(parameter="beta", value=.2)` for the targets. Optional condition-specific reference rows support multiple scenarios, but multiple N/T combinations are not required.

- `source="manual"` (default): a long table with design, replication, parameter,
  estimate, sd, lower, upper and max_psr. Each replication has one whole-fit
  maximum PSR; supply it once and leave other parameter rows NA, or repeat the
  same number. The maximum is compared directly with the shared cutoff.
  Keep one NA placeholder row for each failed replication. There is no runs input.
- `source="mcmc"`: one mcmc.list per replication plus metadata. Point estimates
  are pooled posterior medians; SDs and equal-tailed intervals use the retained
  draws. PSR uses the unsplit variance-ratio formula and its chain means. No ESS/MCSE.
- `source="mplus"`: a vector of existing per-replication .out paths plus metadata
  and map. MplusAutomation reads the results, including native final TECH8 PSR.
  A multi-replication summary output must first be converted into per-replication
  results. All map columns except parameter automatically identify output rows,
  including supplied level/group identifiers. Standard estimate/SD/CI columns
  are read from fixed columns. List only the parameters of interest in map.

For mplus/mcmc, metadata has design and replication, one row per input in the same order; condition is optional. Keep missing-file paths or NULL chain entries for failed fits. Design/condition are your own labels, not algorithm selectors. See ?evaluate_pmd for manual and posterior examples, and ?obtain_map for map preparation using your own Mplus output.

```r
population_value <- data.frame(parameter="beta", value=.2)
e <- data.frame(design="anchor25", replication=1:4, parameter="beta",
  estimate=c(.19,.22,.50,NA_real_), sd=c(.05,.05,.05,NA_real_),
  lower=c(.09,.12,.40,NA_real_), upper=c(.29,.32,.60,NA_real_),
  max_psr=c(1.01,1.03,1.12,NA_real_))
p <- evaluate_pmd(e, population_value, cutoff=1.05,
  max_abs_relative_bias=.1)
p # prints designs meeting the criteria, plus the evaluation table
attr(p, "design_summary") # one row per condition/design: eligible and reason
attr(p, "replications")   # PSR, cutoff, convergence, import errors per fit
attr(p, "estimates")      # parameter results, without a converged column
attr(p, "diagnostics")    # diagnostic tables per fit
```

## PSR and evaluation rules

Every replication uses the same model factor count and PSR cutoff. Supply either one n_factors value or an explicit cutoff. Factor counts are not read from a per-fit manifest. n_factors=1 defaults to 1.05; all other counts (including >2) default to 1.10. A finite positive max_psr must be strictly below cutoff. An explicit cutoff works without n_factors; missing both is an input error.

For m chains and n retained draws, W is mean within-chain sample variance, B is n times the sample variance of chain means, and PSR=sqrt(((n-1)*W/n+B/n)/W). There is no splitting, rank normalization, correction, clamping or rounding. burnin=0 discards no additional stored rows. prob=.95 gives equal-tailed 95% posterior intervals; it only applies to mcmc. Mplus uses one combined rule: final TECH8 PSR below cutoff, errors_flag=FALSE, and final TECH8 iteration below max_iterations (default 50000). Equality with either limit fails. The error flag is FALSE when length(out$errors)<=1; otherwise it is FALSE only if PSR passes and the unlisted error text does not contain THE MODEL ESTIMATION DID NOT TERMINATE NORMALLY. List length is measured before unlisting. Missing/nonfinite PSR or iteration cannot establish convergence. No alternative rule or additional out$converged check is used.

Pass max_iterations directly to evaluate_pmd(source="mplus"), read_mplus_estimates or mplus_convergence, for example max_iterations=80000. TECH8 uses the fixed psr and iteration columns directly; there is no column-name inference or duplicate-column check. Unavailable or nonfinite diagnostics are classified as nonconverged. It checks existing Mplus results; it does not set or run Mplus iterations. Manual and MCMC input retain their PSR checks without this Mplus iteration limit. Inspect attr(result,"diagnostics")[[i]] for last_iteration, max_iterations, iteration_limit_reached and errors_flag.

Convergence rate counts every supplied replication. Other metrics use converged finite point estimates; interval and SD summaries additionally require finite values. Across-replication mean_estimate remains a mean of point estimates, including when each MCMC estimate is a posterior median.

| Criterion | Default | Customize |
|---|---|---|
| PSR per replication | <1.05 for one factor; <1.10 otherwise | n_factors or explicit cutoff |
| Final Mplus TECH8 iteration | <50000 | max_iterations |
| Absolute relative bias | <=0.10 | max_abs_relative_bias=.1 for +/-10% |
| Coverage | [0.91,0.98], inclusive | min_coverage, max_coverage |
| Power for nonzero population values | >=0.80 | min_power |
| Type I error for exactly zero values | [0.025,0.075], inclusive | min_typeI_error, max_typeI_error |
| Convergence rate, RMSE, means, bias, SDs | No screening cutoff | Reported only |

Pass screening cutoff arguments directly to evaluate_pmd; NULL disables a bound. All targets must pass applicable active criteria. eligible/reason appear in the returned table; design_summary gives the design-level result. Eligibility refers to this scenario, its targets and cutoffs; it does not require a minimum convergence rate. Missing required metrics or no usable estimates prevent a pass. Use screen_designs to rescreen a selected target set without changing the original evaluation's eligibility columns.

exclude_rbias=NULL attempts relative bias for every target. Supply exact names, e.g. exclude_rbias=c("intercept","small_effect"), to skip its calculation and screening for those parameters. No numerical tolerance is used. An exactly zero reference always produces NA relative bias; explicitly exclude that parameter when enabling a relative-bias limit. Other metrics and exact-zero classification remain unchanged.

Every value in population_value is interpreted as the known or assumed population parameter underlying the repeated datasets. Estimates from one actual dataset do not automatically become known population values.

The Mplus route directly calls read_mplus_estimates using unstandardized and exactly est, posterior_sd, lower_2.5ci and upper_2.5ci. All four numeric columns must exist; missing columns cause an import error. There is no fallback to se. Put paramHeader, param and any needed BetweenWithin/group identifier in map; all columns except parameter participate automatically. Each requested parameter must match exactly one row. List only the parameters of interest, including those in population_value; other model parameters need not appear in map. Results follow map row order. The model-level TECH8 PSR/error/iteration check still uses the fitted model's diagnostics. Prepare manual input for output that uses a different format.

Interval exclusion means lower>0 or upper<0; an endpoint of zero does not reject. No ESS, valid rate, mean interval width or performance MCSE is computed.

The evaluation tables store convergence only in `attr(p, "replications")`. `attr(p, "estimates")` has no `converged` column. Metric calculation matches each parameter row to its replication record by condition, design and replication, then uses the record's convergence flag. Original diagnostic outputs remain available separately; standalone diagnostic functions still report convergence.

## Parallel processing and help

pmd_batch and evaluate_pmd automatically use parallel::parLapply with PSOCK workers on Windows and parallel::mclapply on macOS/Linux. mc.cores is a positive integer with default 1 on every platform. Windows starts the requested number of workers; macOS/Linux process serially at 1. Windows workers receive current library paths and ordinary referenced design objects such as items/subsets; clusters close on return or error. Per-replication/design PMD seeds and the caller's RNG kind make results reproducible across core counts and backends. No nested parameter/chain parallelism is added.

All exported functions have Rd help specifying choices, numeric bounds, column schemas, defaults and examples. Start with ?pmd_forms, ?pmd_occasions, ?pmd_batch, ?evaluate_pmd and ?mcmc_diagnostics. Examples 01-05 demonstrate designs, manual input, posterior input, existing Mplus output and existing-data batches.

Optional packages: lavaan for CFA; coda for posterior input; MplusAutomation for output reading; rstudioapi for optional installation dialogs. There is no analysis callback in pmd_batch. Complete data generation is available separately through generate_mplus_data; pmd_batch consumes existing datasets.
