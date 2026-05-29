# Autoencoder Architecture

> The Tier 2 engine uses a deep PyTorch Autoencoder to detect financial anomalies by compressing and reconstructing claim features.

The autoencoder is designed for unsupervised anomaly detection. It consists of an **Encoder** that compresses the input vector $x$ into a lower-dimensional latent bottleneck representation $z$, and a **Decoder** that reconstructs the original vector as $x'$:

```
Input x (Dimensions: 4)
   │
   ▼   [Fully Connected Layer: 4 -> 8]
Encoder (ReLU)
   │
   ▼   [Fully Connected Layer: 8 -> 2]
Latent Bottleneck z (Dimensions: 2)
   │
   ▼   [Fully Connected Layer: 2 -> 8]
Decoder (ReLU)
   │
   ▼   [Fully Connected Layer: 8 -> 4]
Output x' (Reconstruction)
```

The model is trained on normal, historical billing data. When it processes an anomalous claim (such as an upcoded charge), the bottleneck layer cannot capture the out-of-distribution patterns, resulting in a high reconstruction loss.

## Key Details
- **Input Dimensions**: 4 (Normalized claim features).
- **Latent Bottleneck Dimensions**: 2 (Forces feature compression).
- **Framework**: PyTorch (`torch.nn.Module`).
- **Hidden Layers**: Fully connected linear layers with ReLU activation functions.
- **Decoupled Output Layer**: Linear layer without sigmoid saturation, allowing Z-score outlier scaling.

## See Also
[[Reconstruction Loss Formula]] · [[Dynamic Threshold Logic]] · [[Embedded Python in IRIS]]