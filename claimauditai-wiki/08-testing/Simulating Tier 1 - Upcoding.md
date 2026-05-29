# Simulating Tier 1 - Upcoding

> Upcoding is simulated by submitting a high-value critical care claim for a patient whose ingested progress notes describe a routine yearly checkup.

To test the Tier 1 Clinical Auditor, we simulate an upcoded billing scenario:

1. **Ingest Low-Severity Clinical Notes**: We POST a patient progress note bundle describing a simple, routine checkup:
   ```json
   "content": [{
     "attachment": {
       "contentType": "text/plain",
       "data": "Patient visited today for a routine yearly physical checkup. General health is excellent..."
     }
   }]
   ```
2. **Submit Anomalous High-Severity Claim**: We submit a claim requesting $2,500 for CPT code 99291 (Complex Critical Care evaluation, 30-74 minutes).

The Clinical Auditor generates semantic embeddings for both texts. It detects a severe clinical-procedural mismatch, yielding a vector similarity score of **`0.3486`** (well below the `0.38` safety threshold), and flags the claim as an upcoding anomaly.

## Key Details
- **CPT Code Simulated**: `99291` (Critical Care evaluation).
- **Clinical Note Narrative**: "Routine yearly physical checkup".
- **Similarity Score Triggered**: `0.3486` (threshold $0.38$).
- **Expected Action**: The claim is intercepted and mutated into a HOLD response.

## See Also
[[Testing Overview]] · [[Tier 1 - Semantic Clinical Auditor]] · [[VECTOR_COSINE Query Pattern]]