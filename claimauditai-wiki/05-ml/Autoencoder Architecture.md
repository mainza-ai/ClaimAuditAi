# Autoencoder Architecture

> The Tier 2 engine uses a deep PyTorch Autoencoder to detect financial anomalies by compressing and reconstructing claim features.

The autoencoder is designed for unsupervised anomaly detection. It consists of an **Encoder** that compresses the input vector $x$ into a lower-dimensional latent bottleneck representation $z$, and a **Decoder** that reconstructs the original vector as $x'$:

```
Input x (Dimensions: 5)
   │
   ▼   [Fully Connected Layer: 5 -> 16]
Encoder (ReLU)
   │
   ▼   [Fully Connected Layer: 16 -> 8]
Latent Bottleneck z (Dimensions: 8)
   │
   ▼   [Fully Connected Layer: 8 -> 4]
Decoder (ReLU)
   │
   ▼   [Fully Connected Layer: 4 -> 5]
Output x' (Reconstruction)
```

The model is trained on normal, historical billing data from `ClaimAudit.ClaimProjections`. When it processes an anomalous claim (such as an upcoded charge), the bottleneck layer cannot capture the out-of-distribution patterns, resulting in a high reconstruction loss.

## Minimum Training Data
The autoencoder requires at least **5 real claims** in `ClaimAudit.ClaimProjections` to train a meaningful model. If the table has fewer than 5 rows, the training is skipped and the autoencoder tier is gracefully bypassed. The `LoadSampleData` endpoint seeds 8 claims into `ClaimProjections`, meeting the threshold.

## Key Details
- **Input Dimensions**: 5 (BilledAmount, ItemCount, SpecialtyCode, PatientAge, DurationDays).
- **Latent Bottleneck Dimensions**: 8 (deep compression with expansion layer).
- **Framework**: PyTorch (`torch.nn.Module`).
- **Hidden Layers**: Fully connected linear layers with ReLU activation functions.
- **Training Data Source**: `ClaimAudit.ClaimProjections` table (populated by seed_fast.py and LoadSampleData).

## See Also
[[Reconstruction Loss Formula]] · [[Dynamic Threshold Logic]] · [[Embedded Python in IRIS]]