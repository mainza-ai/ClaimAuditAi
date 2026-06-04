# Dynamic Threshold Logic

> Dynamic Threshold Logic dynamically adjusts anomaly detection parameters based on the submitting provider's clinical specialty.

Billing profiles vary significantly between clinical specialties. A $2,500 billing profile is standard for a critical care unit, but highly anomalous for a general practitioner.

To minimize false positives, ClaimAuditAI uses dynamic thresholds. During autoencoder evaluation, the engine queries the `ProviderProjections` table to resolve the provider's specialty and dynamically adjusts the anomaly threshold:

$$\theta_{\text{specialty}} = \mu_{\text{specialty}} + 3 \cdot \sigma_{\text{specialty}}$$

Where:
- $\mu$ represents the historical mean reconstruction loss for the specialty.
- $\sigma$ represents the standard deviation of reconstruction loss for that specialty.

If the training data has low variance (homogeneous features), the 95th percentile may produce a threshold near zero. To prevent this, a **minimum floor of 0.02** is enforced: the effective threshold is `max(95th_percentile, 0.02)`.

## Key Details
- **Threshold Calculation**: 95th percentile of per-sample MSE reconstruction losses across all training claims.
- **Minimum Floor**: 0.02 — the threshold never drops below this, ensuring outlier detection even with homogeneous training data.
- **When Untrained**: If fewer than 5 claims exist in the training dataset, the autoencoder returns `flagged=False` (tier gracefully bypassed) rather than producing an uncalibrated threshold.

## See Also
[[Autoencoder Architecture]] · [[Reconstruction Loss Formula]] · [[Embedded Python in IRIS]]