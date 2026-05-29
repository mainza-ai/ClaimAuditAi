# Reconstruction Loss Formula

> Reconstruction loss measures the Mean Squared Error (MSE) between the input claim vector and the output vector reconstructed by the autoencoder.

The reconstruction loss acts as our anomaly score. Because the autoencoder bottleneck is trained on typical billing profiles, it reconstructions standard claims with minimal error. Anomalous claims, however, yield high reconstruction loss.

We calculate the loss using the Mean Squared Error (MSE) formula:

$$L(x, x') = \frac{1}{d} \sum_{i=1}^{d} (x_i - x'_i)^2$$

Where:
- $d$ represents the input dimensions (4).
- $x_i$ represents the normalized input feature value.
- $x'_i$ represents the reconstructed feature value returned by the decoder.

If $L(x, x') > 	heta$ (where $	heta$ is our anomaly threshold, $0.47315$), the system flags the claim as an outlier.

## Key Details
- **Loss Metric**: Mean Squared Error (MSE).
- **Input Dimensions ($d$)**: 4.
- **Anomaly Threshold ($	heta$)**: $0.47315$.
- **Adjudication Rule**: Reconstruction losses exceeding the threshold trigger an immediate anomaly flag.

## See Also
[[Autoencoder Architecture]] · [[Dynamic Threshold Logic]] · [[Embedded Python in IRIS]]