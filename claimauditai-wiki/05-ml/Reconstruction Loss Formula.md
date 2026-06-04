# Reconstruction Loss Formula

> Reconstruction loss measures the Mean Squared Error (MSE) between the input claim vector and the output vector reconstructed by the autoencoder.

The reconstruction loss acts as our anomaly score. Because the autoencoder bottleneck is trained on typical billing profiles, it reconstructions standard claims with minimal error. Anomalous claims, however, yield high reconstruction loss.

We calculate the loss using the Mean Squared Error (MSE) formula:

$$L(x, x') = \frac{1}{d} \sum_{i=1}^{d} (x_i - x'_i)^2$$

Where:
- $d$ represents the input dimensions (5: BilledAmount, ItemCount, SpecialtyCode, PatientAge, DurationDays).

...

If $L(x, x') > \theta$ (where $\theta$ is the anomaly threshold), the system flags the claim as an outlier.

## Key Details
- **Loss Metric**: Mean Squared Error (MSE).
- **Input Dimensions ($d$)**: 5.
- **Anomaly Threshold ($\theta$)**: `max(95th percentile of training losses, 0.02)` — minimum floor prevents undetectable outliers from homogeneous training data.
- **Adjudication Rule**: Reconstruction losses exceeding the threshold trigger an immediate anomaly flag.

## See Also
[[Autoencoder Architecture]] · [[Dynamic Threshold Logic]] · [[Embedded Python in IRIS]]