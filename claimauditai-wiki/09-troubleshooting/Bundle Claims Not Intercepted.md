# Bundle Claims Not Intercepted

> **Symptom:** Claims submitted inside a FHIR Bundle (via `POST /fhir/r4` with a Bundle resource) are saved normally without triggering the AI audit engine. Only direct `POST /fhir/r4/Claim` submissions are intercepted.

## Root Cause

The `OnBeforeRequest` interceptor in `Interactions.cls` only checked `pFHIRRequest.Type = "Claim"`. When a FHIR Bundle is submitted, `pFHIRRequest.Type` is `"Bundle"`, and the interceptor skipped the audit logic entirely.

```objectscript
// Original — only intercepted direct Claim POSTs
If (pFHIRRequest.Type = "Claim") && $IsObject(pFHIRRequest.Json) {
    Set claimJson = pFHIRRequest.Json
    Do ##class(ClaimAudit.AI.Engine).AuditClaim(claimJson, .tAuditResult)
    ...
}
```

Bundles containing Claim entries bypassed all three AI tiers — NLP semantic audit, autoencoder profiling, and collusion network analysis.

## Fix

Extracted the audit logic into a reusable `AuditSingleClaim()` method. Updated `OnBeforeRequest` to handle both direct Claims and Bundle entries:

```objectscript
If pFHIRRequest.Type = "Claim" {
    Do ..AuditSingleClaim(pFHIRRequest.Json)
} ElseIf (pFHIRRequest.Type = "Bundle") && $IsObject(pFHIRRequest.Json.entry) {
    Set tIter = pFHIRRequest.Json.entry.%GetIterator()
    While tIter.%GetNext(.tKey, .tEntry) {
        If $IsObject(tEntry.resource) && (tEntry.resource.resourceType = "Claim") {
            Do ..AuditSingleClaim(tEntry.resource)
        }
    }
}
```

## Affected Files
- `src/cls/ClaimAudit/FHIR/Interactions.cls` — `OnBeforeRequest()`, new `AuditSingleClaim()` method

## Verification
Submit a Bundle containing a Claim resource with an anomalous CPT/ICD mismatch. The ClaimResponse should show `outcome = "queued"` and a Task should be created for review.
