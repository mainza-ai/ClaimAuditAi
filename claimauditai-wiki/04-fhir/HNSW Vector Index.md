# HNSW Vector Index

> The HNSW (Hierarchical Navigable Small World) index enables ultra-fast, high-dimensional vector similarity queries within the IRIS database kernel.

ClaimAuditAI uses native InterSystems Vector Search capabilities to index clinical text embeddings. We define the schema and construct the HNSW vector index using dynamic SQL inside the engine initialization script:

```sql
-- 1. Create table with vector column
CREATE TABLE ClaimAudit.ClinicalNotes (
  NoteId VARCHAR(100) PRIMARY KEY,
  PatientId VARCHAR(100),
  NoteEmbedding VECTOR(DOUBLE, 384)
);

-- 2. Build HNSW vector index
CREATE INDEX HNSW_Embedding_Idx 
ON ClaimAudit.ClinicalNotes (NoteEmbedding) 
USING HNSW;
```

The HNSW index optimizes search speeds, allowing our clinical auditor to perform sub-millisecond semantic similarity lookups across thousands of unstructured patient progress notes.

## Key Details
- **Index Type**: Hierarchical Navigable Small World (HNSW).
- **Dimensionality**: 384 (Matches the Output of `all-MiniLM-L6-v2`).
- **Distance Metric**: Cosine Similarity.
- **Engine Layer**: Executes natively within the database process memory space, utilizing SIMD hardware acceleration.

## See Also
[[Tier 1 - Semantic Clinical Auditor]] · [[VECTOR_COSINE Query Pattern]] · [[Initialization Script]]