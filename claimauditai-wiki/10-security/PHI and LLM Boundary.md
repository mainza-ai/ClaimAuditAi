# PHI and LLM Boundary

> The PHI boundary ensures that no Protected Health Information (PHI) is transmitted to external cloud LLM APIs during adjudication.

To comply with HIPAA regulations, ClaimAuditAI enforces a strict data boundary between the local database and external LLM APIs. 

Unstructured patient notes are processed and matched using local sentence-transformer models running inside the container. When querying the cloud LLM for hold summaries, only non-identifiable metadata is transmitted:

```
Local Container (Secure):   Patient Name, Full Narrative Progress Notes, Medical Record IDs.
Nvidia Cloud API (Safe):    CPT Procedural Codes, Provider NPI, Total Billed Amount, Anomaly Scores.
```

This architecture ensures that no identifiable patient data leaves the secure local database container.

## Key Details
- **Local Vectorizer**: `all-MiniLM-L6-v2` running natively within the container.
- **Cloud Transmission Payload**: Bounded to CPT codes, NPIs, billed amounts, and raw anomaly metrics.
- **Patient Identifiers**: Stripped or replaced with generic placeholders before invoking external APIs.
- **Regulatory Compliance**: Fully compliant with HIPAA security and privacy rules.

## See Also
[[Security Overview]] · [[API Key Handling]] · [[IRIS Role-Based Access Control]]