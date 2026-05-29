# Simulating Tier 2 - Unbundling

> Unbundling and financial anomalies are simulated by submitting a claim with extreme billing charges that trigger high autoencoder reconstruction loss.

To test the Tier 2 Statistical Outlier Profiler, we submit a claim containing billing anomalies (such as extreme charges or excessive procedure codes). The profiler normalizes these features and passes them through our PyTorch Autoencoder.

Because the model was trained on standard billing profiles, it cannot reconstruct this outlier vector accurately. This yields a massive reconstruction loss of **`577.46790`** (vastly exceeding the `0.47315` threat threshold), immediately flagging the claim as a financial outlier.

## Key Details
- **Feature Vector Tested**: Normalized total billed amount, line items, and provider specialty.
- **Reconstruction Loss Triggered**: `577.46790` (threshold $0.47315$).
- **Machine Learning Core**: Local CPU PyTorch autoencoder execution.
- **Expected Action**: Interceptor mutates the HTTP response and registers an audit task.

## See Also
[[Testing Overview]] · [[Tier 2 - Statistical Outlier Profiler]] · [[Reconstruction Loss Formula]]