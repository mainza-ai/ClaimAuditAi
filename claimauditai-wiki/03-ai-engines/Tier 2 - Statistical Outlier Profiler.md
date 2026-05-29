# Tier 2 - Statistical Outlier Profiler

> The Tier 2 engine profiles claims using an unsupervised PyTorch Autoencoder to detect financial anomalies and billing irregularities.

The profiler transforms incoming claim variables (e.g. total billed amount, line items, provider specialties) into numerical vectors. These are passed through a pre-trained bottleneck autoencoder model:

```
Input (x) ──> Encoder ──> Latent Bottleneck (z) ──> Decoder ──> Output (x')
```

The system calculates the reconstruction loss between the input $x$ and output $x'$. Claims representing billing anomalies (such as extreme upcoded charges) cannot be reconstructed accurately by the bottleneck network, resulting in very high reconstruction loss. If the loss exceeds the Dynamic Threshold ($0.47315$), the engine flags the claim as a statistical outlier.

## Key Details
- **Framework**: PyTorch (`torch` running natively in Embedded Python).
- **Input Dimensions**: 4 (Normalized claim features).
- **Default Threshold**: $0.47315$ (MSE loss above this triggers an anomaly flag).
- **Execution Mode**: Local CPU inference within the database transaction thread.

## See Also
[[Three-Tier AI Engine Overview]] · [[Autoencoder Architecture]] · [[Reconstruction Loss Formula]]