# Tier 1 - Semantic Clinical Auditor

> The Tier 1 engine uses semantic vector search to check if unstructured clinical progress narratives support the billed CPT codes.

When a claim is submitted, the clinical auditor generates a semantic vector embedding of the billed CPT code's description using the `all-MiniLM-L6-v2` transformer model (384 dimensions). It then executes a high-performance native SQL query against the `ClaimAudit.ClinicalNotes` database table:

```sql
SELECT TOP 1 NoteId, SimilarityScore 
FROM (
  SELECT NoteId, VECTOR_COSINE(NoteEmbedding, TO_VECTOR(?, DOUBLE, 384)) AS SimilarityScore 
  FROM ClaimAudit.ClinicalNotes 
  WHERE PatientId = ?
) 
ORDER BY SimilarityScore DESC
```

If the highest similarity score falls below our safety threshold ($0.38$), the auditor flags the claim for potential upcoding (e.g. billing for intensive critical care when the clinical notes describe a routine yearly checkup).

## Key Details
- **Model**: `all-MiniLM-L6-v2` (Local SentenceTransformer).
- **Dimensions**: 384.
- **Safety Threshold**: $0.38$ (Scores below this trigger an anomaly flag).
- **Database Index**: Native HNSW index on the `NoteEmbedding` column.

## See Also
[[Three-Tier AI Engine Overview]] · [[HNSW Vector Index]] · [[VECTOR_COSINE Query Pattern]]