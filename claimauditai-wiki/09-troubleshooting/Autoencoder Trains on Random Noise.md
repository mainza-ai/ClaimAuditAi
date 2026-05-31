# Autoencoder Trains on Random Noise

> **Symptom:** The autoencoder flags claims randomly with no discernible pattern. Some low-value, clearly valid claims are flagged while high-value suspicious ones pass through. The `evaluate_claim_anomaly()` function produces inconsistent results.

## Root Cause

When fewer than 10 real claims existed in the `ClaimAudit.ClaimProjections` table, the training code generated **200 synthetic random claims** using `np.random.normal()` and `np.random.poisson()` distributions. The autoencoder was trained on pure noise, producing a meaningless reconstruction loss threshold.

```python
# Original code — TRAINED ON NOISE
if len(historical_claims) < 10:
    n_samples = 200
    billed_amount = np.random.normal(150, 40, n_samples)
    item_count = np.random.poisson(2, n_samples) + 1
    ...
```

The resulting anomaly threshold could not distinguish real outliers from normal claims — it was an arbitrary cutoff on randomly sampled data with no relationship to actual claim patterns.

## Fix

- Removed the synthetic data generation entirely
- Added a minimum threshold: **5 real claims required** to train a meaningful model
- If fewer than 5 real claims exist, the autoencoder returns `{status: "skipped"}` — the tier is gracefully bypassed

```python
# Fixed — requires real data
if len(historical_claims) < 5:
    return {"status": "skipped", "message": f"Insufficient training data ({len(historical_claims)} < 5)."}
```

## Related Issue: Hardcoded Engine Features

The `Engine.AuditClaim()` method feeds the autoencoder with hardcoded default values for `specialtyCode` (1), `patientAge` (45), and `durationDays` (1). Only `billedAmount` comes from the actual claim data. The seed now populates `ClaimAudit.ClaimProjections` with these values, making them consistent between training and evaluation.

## Affected Files
- `src/python/autoencoder_train.py` — `train_autoencoder()` function
- `src/cls/ClaimAudit/AI/Engine.cls` — `AuditClaim()` defaults documented

## Verification
The autoencoder tier is only useful after at least 5 real claims have been submitted. Use the `loadSampleData` endpoint or the Data Management page to seed sample claims, which populates `ClaimProjections` with 8 rows of training data.
