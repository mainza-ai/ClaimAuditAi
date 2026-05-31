# Claim Actions Silently Fail

> **Symptom:** Calling `POST /api/claims/:id/approve`, `/reject`, or `/escalate` returns `{"status":"success"}` but the claim stays in the hold queue, Task status remains unchanged, and ClaimResponse outcome is not updated.

## Root Cause

The FHIR `DispatchRequest` PUT silently fails (HTTP 400) when the `valueDateTime` field in the authorizer extension uses an invalid datetime format. The `success` response is written unconditionally outside the `If $IsObject()` guard, masking the failure.

### Incorrect Datetime Format

The original code produced:
```objectscript
$ZDateTime($Horolog, 3, 1)  →  "2026-05-31 03:28:12"
```

This format has two problems for FHIR validation:
1. **Space separator** instead of `T` between date and time
2. **No timezone suffix** (`Z` for UTC) required by FHIR `dateTime` regex

FHIR rejects this with:
```json
{
  "severity": "error",
  "code": "invalid",
  "diagnostics": "<HSFHIRErr>MalformedValue",
  "details": {
    "text": "The value '2026-05-31 03:28:12' of Property 'valueDateTime' is a malformed 'dateTime'."
  }
}
```

### Additional Causes

1. **Task owner reference with spaces:** `{"reference": "Practitioner/Dir. Jane"}` — FHIR resource references cannot contain spaces in the ID segment.
2. **Success written outside guard:** The `Write {"status":"success"}` was placed after the `If $IsObject()` closing brace, so it ran even when the ClaimResponse was not found or the PUT failed.

## Fix

1. **Use ISO 8601 format for all datetime extensions:**
```objectscript
Set tDt = $ZDATE($PIECE($HOROLOG,",",1),3)_"T"_$ZTIME($PIECE($HOROLOG,",",2),1)_"Z"
// Produces: "2026-05-31T03:28:12Z"
```

2. **Use sanitized Practitioner reference:**
```objectscript
Set tTaskJson.owner = {"reference": "Practitioner/auditor", "display": (tAuthorizedBy)}
```

3. **Move success Write inside the guard:**
```objectscript
If '$IsObject(tResponse.Json) {
    Set %response.Status = 404
    Write {"error": "ClaimResponse not found"}.%ToJSON()
    Quit
}
// ... processing ...
Write {"status": "success"}.%ToJSON()
```

## Affected Files
- `src/cls/ClaimAudit/REST/Router.cls` — `ApproveClaim()`, `RejectClaim()`, `EscalateClaim()`

## Verification
```bash
curl -s -X POST http://localhost:3000/api/claims/17/approve \
  -H 'Content-Type: application/json' \
  -d '{"authorizedBy":"Auditor Smith","rationaleSummary":"Valid clinical necessity."}'

# Verify: held count should decrease by 1, the claim should leave the hold queue,
# and the ledger should show an entry with action="approved" and authorizer="Auditor Smith"
```

## See Also
[[Rejected Claims Missing From Ledger]] · [[Dashboard Metrics Stale After Actions]]
