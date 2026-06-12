# Autoencoder Architecture

> The Tier 2 engine uses a deep PyTorch Autoencoder to detect financial anomalies by compressing and reconstructing claim features.

The autoencoder is designed for unsupervised anomaly detection. It consists of an **Encoder** that compresses the input vector $x$ into a lower-dimensional latent bottleneck representation $z$, and a **Decoder** that reconstructs the original vector as $x'$:

```
Input x (Dimensions: 5)
   │
   ▼   [Fully Connected Layer: 5 -> 16]  + ReLU
Encoder (compression)
   │
   ▼   [Fully Connected Layer: 16 -> 8]  + ReLU
   │
   ▼   [Fully Connected Layer: 8 -> 4]   + ReLU
Latent Bottleneck z (Dimensions: 4)
   │
   ▼   [Fully Connected Layer: 4 -> 8]   + ReLU
Decoder (expansion)
   │
   ▼   [Fully Connected Layer: 8 -> 16]  + ReLU
   │
   ▼   [Fully Connected Layer: 16 -> 5]  (linear, no activation)
Output x' (Reconstruction)
```

The model is trained on normal, historical billing data from `ClaimAudit.ClaimProjections`. When it processes an anomalous claim (such as an upcoded charge), the bottleneck layer cannot capture the out-of-distribution patterns, resulting in a high reconstruction loss.

## Minimum Training Data
The autoencoder requires at least **5 real claims** in `ClaimAudit.ClaimProjections` to train a meaningful model. If the table has fewer than 5 rows, the training is skipped and the autoencoder tier returns `flagged=False` (gracefully bypassed — was previously `flagged=True` which incorrectly flagged all claims when training was unavailable).

Once trained, the anomaly threshold has a **minimum floor of 0.02** — even with homogeneous training data, the threshold cannot drop below this value, ensuring outliers remain detectable. The effective threshold is `max(95th_percentile, 0.02)`.

The `LoadSampleData` endpoint seeds 8 claims with diversified features (ages 23-78, item counts 1-4, duration 1-7 days) to produce a realistic mix of normal and outlier patterns.

## Model Training & Drift Safeguards
To prevent model degradation and ensure training reliability in production environments, the autoencoder training pipeline implements several validation safeguards:
- **Validation Split (15%)**: During retraining, 15% of historical claim projections are reserved for validation, while the remaining 85% are used for training.
- **Validation Drift Checking (15% Limit)**: Prior to replacing the active model file (`autoencoder_model.pth`), the candidate model is evaluated on the validation dataset. If its reconstruction loss exceeds the baseline model's loss by more than **15%**, training is rejected with an error/warning message, and the previous model file remains active.
- **Rolling Backups (3 Versions)**: The system maintains a rolling backup of the last 3 successfully trained model weights and stats (`_v1.pth/npz`, `_v2.pth/npz`, `_v3.pth/npz`) for fast rollback recovery.
- **Weight Determinism**: PyTorch seed setting (`torch.manual_seed(42)`) is executed right before model instantiation to ensure identical initial weights across identical sequential runs, eliminating non-deterministic loss variance.

## Key Details
- **Input Dimensions**: 5 (BilledAmount, ItemCount, SpecialtyCode, PatientAge, DurationDays).
- **Latent Bottleneck Dimensions**: 4 (encoder: 5→16→8→4; decoder: 4→8→16→5).
- **Output Activation**: Linear (no activation function) — correct for MSE reconstruction loss.
- **Framework**: PyTorch (`torch.nn.Module`).
- **Hidden Layers**: Fully connected linear layers with ReLU activation functions; no sigmoid activations.
- **Training Data Source**: `ClaimAudit.ClaimProjections` table (populated by LoadSampleData).
- **Minimum Threshold Floor**: 0.02 (prevents false negatives at extremely low reconstruction losses).
- **Validation Drift Limit**: 15% (rejects updates that degrade validation metrics).
- **Model Backup Versions**: 3 (rolling rotation).

## See Also
[[Reconstruction Loss Formula]] · [[Dynamic Threshold Logic]] · [[Embedded Python in IRIS]]