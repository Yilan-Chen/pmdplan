# Evaluation thresholds

| Check | Default | Customization |
|---|---|---|
| Per-fit PSR, all three sources | Strictly <1.05 if n_factors=1; <1.10 otherwise | n_factors or explicit cutoff |
| Final Mplus TECH8 iteration | <50000 | max_iterations |
| Absolute relative bias | <=0.10 | max_abs_relative_bias; .1 means +/-10% |
| Coverage | Inclusive [0.91,0.98] | min_coverage, max_coverage |
| Power for nonzero population values | >=.80 | min_power |
| Type I error for zero population values | Inclusive [.025,.075] | min_typeI_error, max_typeI_error |

PSR equality does not pass. Nonfinite or unavailable PSR does not pass. Counts greater than two still use 1.10. The maximum is over monitored parameters in a fit, not over earlier checkpoints. Mplus uses the final native TECH8 maximum; posterior input computes the unsplit variance-ratio formula over all supplied parameters; manual input supplies the maximum. Convergence rate uses every manifest row.

All screening bounds accept NULL to disable that bound. Convergence rate, RMSE, bias, mean_estimate, empirical_sd and mean_sd have no screening cutoffs. ESS, valid_rate, mean_interval_width and MCSE are not computed.

All design-screening cutoffs can be supplied directly to evaluate_pmd. exclude_rbias skips relative-bias computation and screening for named targets.

Mplus also requires errors_flag=FALSE under the error-list length rule documented in ?mplus_convergence. Its final iteration must be finite and below max_iterations; the iteration limit is a required check and does not accept NULL to disable it. Only the design-screening bounds accept NULL as a disable switch.
