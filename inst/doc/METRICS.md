# Performance metrics

For one condition, design and parameter, let R be the number of attempted replications and K the number with converged, finite point estimates. Let e be estimate minus the supplied reference theta.

| Output | Definition |
|---|---|
| n_attempted | R, including failures |
| n_fit_returned | Number of readable ok/nonconverged attempts |
| n_converged | Number with converged = TRUE |
| n_valid | K |
| n_interval | Number of valid estimates with finite interval bounds |
| n_sd | Number of valid estimates with finite supplied SDs |
| convergence_rate | n_converged / R |
| mean_estimate | Mean of valid point estimates |
| bias | mean(e) |
| relative_bias | mean(e) / theta; 0.10 means 10% |
| rmse | sqrt(mean(e^2)) |
| empirical_sd | Sample SD of valid estimates |
| mean_sd | Mean of available supplied SDs among valid estimates |
| coverage | Fraction of available finite intervals covering population value |
| power | Fraction of usable intervals strictly excluding zero; only for nonzero population value |
| typeI_error | Fraction of usable intervals strictly excluding zero; only for exactly zero population value |

One valid replication permits point summaries, but empirical_sd requires at least two. With no valid estimates, point summaries are NA. Exactly zero references give NA relative bias. All nonzero references are used without a tolerance; exclude_rbias names targets whose relative bias is omitted. An excluded parameter also skips relative-bias screening. relative_bias_defined records whether the reference is nonzero; relative_bias_excluded records explicit user exclusion. The denominator is never replaced. Coverage, power and type I error use n_interval, not an assumption that every fit has an interval. Power and type I error classify population values using exact zero; Rejection means lower > 0 or upper < 0. Endpoints equal to zero do not reject. Only the rejection metric applicable to the supplied population value is populated; the other is NA. n_sd and n_interval report the actual available counts.

All references are the known or assumed population values underlying the repeated datasets. Repeated masking of one real dataset does not by itself constitute repeated sampling from a known population.

Specify parameterization and scale explicitly: variance versus log variance, standardized versus unstandardized parameters, and population versus individual parameters are distinct targets. Names alone cannot establish comparability.

`evaluate_pmd()` automatically screens each condition; `screen_designs()` can rescreen selected parameters separately. Coverage must lie in [0.91, 0.98] by default, including both boundaries. min_coverage and max_coverage can be customized independently; setting both to NULL disables this criterion. These limits concern empirical coverage, not the nominal interval probability. All requested parameters must satisfy supplied criteria; unavailable metrics fail the criterion. Convergence rate and RMSE are reported without screening cutoffs. Relative bias has a default absolute limit of 0.10 (NULL disables it); supply threshold arguments by name. Evaluation does not calculate mean_interval_width, valid_rate or Monte Carlo standard errors of the performance metrics. The n_valid count and converged, finite-estimate filter remain in use. Power defaults to a minimum of 0.80 for nonzero population values; typeI_error defaults to [0.025, 0.075] for exactly zero population values. All bounds are inclusive and configurable. The inapplicable metric is ignored during screening. See POWER_TYPE1.md for details of the interval-based decision rule. No SD-bias or weighted overall ranking is inferred.

Reference: Morris, White, and Crowther (2019), https://doi.org/10.1002/sim.8086.

PSR is derived by the selected input route before evaluation. Mplus uses the final native TECH8 maximum; mcmc.list uses the unsplit variance-ratio formula; manual data supplies max_psr per fit. All manifest rows, including import_error rows, remain in the convergence-rate denominator. No ESS is computed.

For MCMC input, each point estimate is a pooled posterior median. mean_estimate is the mean of these medians across usable replications. The result includes design-level eligible/reason and attr(result,"design_summary"). The original PSR chain means are unchanged.

For Mplus, a PSR below cutoff is necessary but not sufficient. The error-list flag must be FALSE and the final TECH8 iteration must be below max_iterations, default 50000. Equality fails. See ?mplus_convergence for the exact error-list length rule and missing-diagnostic handling. These checks apply before metrics are calculated from converged replications.
