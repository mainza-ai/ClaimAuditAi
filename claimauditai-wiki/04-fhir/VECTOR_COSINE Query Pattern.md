# VECTOR_COSINE Query Pattern

> The VECTOR_COSINE SQL query pattern performs high-speed vector similarity lookups to match CPT billing codes against unstructured clinical progress notes.

To check for upcoding anomalies, the Clinical Auditor compares billed CPT descriptions with unstructured notes stored in the database. The matching is performed using the native `VECTOR_COSINE` function:

```sql
SELECT TOP 1 NoteId, SimilarityScore 
FROM (
  SELECT NoteId, VECTOR_COSINE(NoteEmbedding, TO_VECTOR(?, DOUBLE, 384)) AS SimilarityScore 
  FROM ClaimAudit.ClinicalNotes 
  WHERE PatientId = ?
) 
ORDER BY SimilarityScore DESC
```

The input vector must be formatted using the unquoted `TO_VECTOR(?, DOUBLE, 384)` syntax. The system returns the highest similarity score; if it falls below the safety threshold ($0.38$), the claim is flagged as an upcoding anomaly.

## Key Details
- **Native SQL Function**: `VECTOR_COSINE(vector1, vector2)`
- **Datatype Casting**: `TO_VECTOR(value, DOUBLE, dimensions)`
- **Similarity Range**: $0.0$ (orthogonal) to $1.0$ (identical vectors).
- **Safety Threshold**: $0.38$ (lower scores indicate a clinical-procedural mismatch).

## See Also
[[Tier 1 - Semantic Clinical Auditor]] · [[HNSW Vector Index]] · [[Vector Search Returns No Results]]