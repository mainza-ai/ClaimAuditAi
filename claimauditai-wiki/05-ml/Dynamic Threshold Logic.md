# Dynamic Threshold Logic

> Dynamic Threshold Logic dynamically adjusts anomaly detection parameters based on the submitting provider's clinical specialty.

Billing profiles vary significantly between clinical specialties. A $2,500 billing profile is standard for a critical care unit, but highly anomalous for a general practitioner.

To minimize false positives, ClaimAuditAI uses dynamic thresholds. During autoencoder evaluation, the engine queries the `ProviderProjections` table to resolve the provider's specialty and dynamically adjusts the anomaly threshold:

$$\theta_{\text{specialty}} = \mu_{\text{specialty}} + 3 \cdot \sigma_{\text{specialty}}$$

Where:
- $\mu$ represents the historical mean reconstruction loss for the specialty.
- $\sigma$ represents the standard deviation of reconstruction loss for that specialty.

If the specialty has no historical data, the engine falls back to the default baseline threshold of $0.47315$.

## Key Details
- **Baseline Threshold**: $0.47315$.
- **Sensitivity Limit**: Three standard deviations ($3\sigma$) above the specialty's mean loss.
- **Database Dependency**: Queries the `ProviderProjections` table.
- **Specialty Resolution**: Lookups are performed using the provider's NPI.

## See Also
[[Autoencoder Architecture]] · [[Reconstruction Loss Formula]] · [[Embedded Python in IRIS]]