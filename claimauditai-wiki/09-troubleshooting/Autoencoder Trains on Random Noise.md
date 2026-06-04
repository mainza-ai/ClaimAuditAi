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
- If fewer than 5 real claims exist, the autoencoder returns `flagged=False` — the tier is gracefully bypassed (was previously `flagged=True` which incorrectly flagged all claims when training was unavailable)
- Added a **minimum threshold floor of 0.02** — the reconstruction loss threshold cannot drop below this, even with homogeneous training data. The effective threshold is `max(95th_percentile, 0.02)`.
- `LoadSampleData` now runs the table clear **before** the autoencoder warm-up (was after), preventing training on stale data from a previous seed

```python
# Fixed — requires real data
if len(historical_claims) < 5:
    return {"status": "skipped", "message": f"Insufficient training data ({len(historical_claims)} < 5)."}
```

## Related Issue: Feature Extraction

The `Engine.AuditClaim()` method queries `ClaimAudit.ClaimProjections` for `SpecialtyCode`, `PatientAge`, and `DurationDays` per-claim, using the patient key from the incoming claim. This ensures evaluation features match the training data distribution. Prior to this fix, hardcoded defaults (age=45, days=1) were used for all claims, making the autoencoder blind to diverse feature patterns in the training data.

## Verification
The autoencoder tier is only useful after at least 5 real claims have been submitted. Use the `loadSampleData` endpoint or the Data Management page to seed sample claims, which populates `ClaimProjections` with 8 rows of diversified training data (ages 23-78, item counts 1-4, duration 1-7 days). Claim 8 uses `claimaudit-prov` (shares address with prov2) to trigger the graph tier simultaneously, producing the critical test case.
