# Power and type I error

For each condition, design and parameter, the null hypothesis is theta = 0. The decision rule rejects zero when a supplied interval lies strictly on either side of zero: lower > 0 or upper < 0. Both directions count. An endpoint equal to zero includes the null and does not reject.

Let J = n_interval be the number of converged, finite point estimates with both interval bounds finite, and D the number of these intervals excluding zero. The rejection rate is D / J. It is reported as power for nonzero population values and as typeI_error for exactly zero population value. The other output is NA. With J = 0 both are NA. There is no assumption that missing or failed fits are non-rejections: these rates are conditional on usable intervals, as is coverage. n_attempted, n_converged, n_valid and n_interval show availability.

Classification uses the supplied population value, not the point estimate or its significance. A small but nonzero population value still selects power. There is no numerical zero tolerance. exclude_rbias skips relative bias for user-named parameters only.

The evaluator uses the supplied intervals; it neither infers their nominal probability nor constructs or rescales them. Use a consistent interval rule, such as two-sided 95% credible intervals. These empirical operating rates assess that decision rule over repeated datasets; 95% posterior probability alone does not guarantee a 5% repeated-sampling type I error rate. This is not a p-value or Bayes-factor calculation. New MCSE or interval-width outputs are not introduced.

## Screening

Default criteria, all inclusive:

- power >= 0.80 when population value is nonzero;
- 0.025 <= typeI_error <= 0.075 when population value is exactly zero;
- 0.91 <= coverage <= 0.98 for all population targets.

Supply min_power, min_typeI_error and max_typeI_error by name to customize them. NULL disables that criterion or bound. Disable both type I error bounds to turn its screen off. Bounds must be finite numbers between 0 and 1; the lower bound must not exceed the upper bound. Every selected parameter must satisfy its applicable rejection criterion and every other enabled criterion. Missing, nonfinite or out-of-range applicable rates fail an active screen.

For exactly zero population values and the same usable intervals, typeI_error = 1 - coverage. Both configured screens are applied: the default type I error bounds imply coverage in [0.925, 0.975] for zero-valued parameters. For nonzero population values, power is not 1 - coverage: power tests exclusion of zero, while coverage tests inclusion of the actual population value.

Relative bias is undefined at zero population values. Its limit is 0.10 by default. For a zero-valued parameter, explicitly include that parameter in exclude_rbias to skip the unavailable relative-bias criterion.

```r
# performance is returned by evaluate_pmd().
# screen_designs(performance, parameters = c("theta_nonzero", "theta_zero"),
#   min_power = 0.85, min_typeI_error = 0.02, max_typeI_error = 0.08)
# To screen only coverage, set min_power, min_typeI_error and max_typeI_error
# and max_abs_relative_bias to NULL.
```

Reference: Morris, White, and Crowther (2019), https://doi.org/10.1002/sim.8086.
