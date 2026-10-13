# Validation

The package includes 24 regression scripts covering planned-missingness designs,
schedules, data preservation, batch processing, Mplus input generation, parameter
mapping, convergence checks, evaluation metrics and parallel execution.

Run the source-package checks from the directory containing the package:

```sh
R CMD build --no-build-vignettes pmdplan
R CMD check --no-manual --no-build-vignettes pmdplan_0.1.0.tar.gz
```

The checks exercise installed-package examples and regression scripts. Mplus
input generation can be tested with `run = FALSE`; successful file generation
does not establish model convergence. Executing an actual Mplus model requires
a separate local Mplus installation. Parallel tests on macOS do not substitute
for validation on a native Windows installation.
