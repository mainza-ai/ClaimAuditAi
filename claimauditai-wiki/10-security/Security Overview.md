# Security Overview

> ClaimAuditAI implements strict security boundaries to protect Patient Health Information (PHI) and secure database access.

Because the system runs natively within the database process memory space, it does not need to transmit raw PHI to external servers for vector similarity queries or autoencoder profiling:

```
Unstructured Notes (PHI) ──> [SentenceTransformer (Local)] ──> 384-Dim Vector (No PHI) ──> Cloud LLM (Safe)
```

The system ensures that:
1. **Vector Search Security**: Employs local sentence-transformer models to process progress notes.
2. **External Privacy boundaries**: Only non-identifiable metrics (such as CPT codes, provider NPIs, and billed amounts) are sent to cloud LLM APIs.
3. **Internal Access Controls**: Uses role-based access controls to restrict access to the projected data schemas.

## Key Details
- **PHI Scrubbing**: Active pre-adjudication scrubbing on all external API requests.
- **Primary Encryption Key**: Managed securely via InterSystems IRIS KMS (Key Management Suite).
- **Access Rule Policy**: Restricts database write permissions to the `/interop/fhir/r4` service account.

## See Also
[[API Key Handling]] · [[PHI and LLM Boundary]] · [[IRIS Role-Based Access Control]] · [[SMART on FHIR with Keycloak OAuth2]]