# Testing Overview

> Testing ClaimAuditAI involves submitting mock patient progress notes and simulating upcoding, unbundling, and referral fraud vectors.

To verify our payment integrity engines, we submit test payloads using Postman, curl, or our automated Python script `test_claim.py`:

```
POST Clinical Notes (sample_patient_bundle.json) ──> POST Anomalous Claim (sample_claim.json) ──> Assert HTTP 202 HOLD
```

Testing asserts that:
1. **Clinical Narrative Ingestion**: Decodes Base64 progress notes and indexes them in our vector database using SentenceTransformers.
2. **Real-Time Interception**: The strategy interceptor catches anomalous claim profiles pre-payment.
3. **Response Mutation**: The outgoing HTTP status is mutated to `202 Accepted` and all three auxiliary resources are persisted successfully.

## Key Details
- **Primary Test Script**: `test_claim.py` (Exposed in your workspace's `/scratch` directory).
- **Authentication Credentials**: Basic Auth (`_SYSTEM` / `SYS`).
- **Base Verification URL**: `http://localhost:52773/interop/fhir/r4/Claim`
- **Output Assertions**: Verification of the `outcome` (`"queued"`), `disposition` (Markdown explanation), and secondary resource database IDs.

## See Also
[[Simulating Tier 1 - Upcoding]] · [[Simulating Tier 2 - Unbundling]] · [[Simulating Tier 3 - Collusion]]