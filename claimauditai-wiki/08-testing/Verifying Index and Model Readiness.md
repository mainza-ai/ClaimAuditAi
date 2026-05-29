# Verifying Index and Model Readiness

> Before submitting test claims, we must verify that our HNSW vector indexes are built and our PyTorch autoencoders are trained.

We verify index and model readiness by querying the IRIS database state tables and checking model files inside the container:

### 1. Verify Vector Database Index
Execute this SQL command to verify that the HNSW index on the `ClinicalNotes` table is active:
```sql
SELECT INDEX_NAME, INDEX_TYPE, IS_ACTIVE 
FROM INFORMATION_SCHEMA.INDEXES 
WHERE TABLE_NAME = 'ClinicalNotes'
```

### 2. Verify Pre-Trained Model Files
Verify that the pre-trained autoencoder weights (`autoencoder.pth`) and normalization stats (`stats.npz`) exist in the Python directory:
```bash
docker exec claimaudit-iris ls -la /home/irisowner/dev/src/python
```

## Key Details
- **Database Table**: `ClaimAudit.ClinicalNotes`
- **Vector Index Name**: `HNSW_Embedding_Idx`
- **Model Weights File**: `src/python/autoencoder.pth`
- **Normalization Stats File**: `src/python/stats.npz`

## See Also
[[Testing Overview]] · [[HNSW Vector Index]] · [[Autoencoder Architecture]]