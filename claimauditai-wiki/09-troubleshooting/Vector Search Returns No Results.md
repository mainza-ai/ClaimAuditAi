# Vector Search Returns No Results

> Vector search returns no results when casting parameters in dynamic SQL queries use incorrect datatypes or quotes.

### Symptom
Submitting claims throws exceptions like `Datatype Mismatch` or returns empty similarity scores during vector search lookups.

### Diagnostic Steps
1. **Inspect Engine Error Logs**: Check the `^ClaimAuditIndexError` global to inspect vector search exceptions:
   ```bash
   echo 'write ^ClaimAuditIndexError, !' | docker exec -i claimaudit-iris iris session IRIS -U INTEROP
   ```
2. **Check SQL Query Syntax**: Ensure that vector arguments are cast using the unquoted `TO_VECTOR(value, DOUBLE, dimensions)` syntax.

### Resolution
Update your SQL queries to ensure the datatype argument in `TO_VECTOR` is unquoted:
```sql
-- Correct unquoted syntax
SELECT VECTOR_COSINE(NoteEmbedding, TO_VECTOR(?, DOUBLE, 384)) FROM ClaimAudit.ClinicalNotes

-- Incorrect quoted syntax (will fail)
SELECT VECTOR_COSINE(NoteEmbedding, TO_VECTOR(?, 'DOUBLE', 384)) FROM ClaimAudit.ClinicalNotes
```

## See Also
[[Troubleshooting Overview]] · [[HNSW Vector Index]] · [[VECTOR_COSINE Query Pattern]]