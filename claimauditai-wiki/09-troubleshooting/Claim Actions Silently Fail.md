# Claim Actions Silently Fail / Return 404

> **Symptom:** Calling `POST /api/claims/:id/approve`, `/reject`, or `/escalate` returns HTTP 404 Not Found, OR returns `{"status":"success"}` but the claim stays in the hold queue.

## Root Causes

There are three independent root causes that can cause claim actions to fail:

### 1. Missing Route Entries in UrlMap (Cause of 404)

The XData `UrlMap` in `Router.cls` was missing the three claim action routes. The `ApproveClaim()`, `EscalateClaim()`, and `RejectClaim()` methods existed but had no `<Route>` entries — `%CSP.REST` could not match the URL+Method combination, returning 404:

```xml
<!-- MISSING from UrlMap (causes 404): -->
<Route Url="/claims/:id/approve"  Method="POST" Call="ApproveClaim"/>
<Route Url="/claims/:id/escalate" Method="POST" Call="EscalateClaim"/>
<Route Url="/claims/:id/reject"   Method="POST" Call="RejectClaim"/>
```

**Fix:** Add the three route entries to the XData `UrlMap` section in `src/cls/ClaimAudit/REST/Router.cls`.

### 2. PUT Response Not Validated (Cause of Silent Failure)

The `ApproveClaim()`, `EscalateClaim()`, and `RejectClaim()` methods dispatched a `DispatchRequest(PUT)` to update the ClaimResponse but never checked the response status code. If the PUT failed (e.g., FHIR validation errors), the method still wrote `{"status":"success"}`.

**Fix:** Check `$EXTRACT(tRespPut.Status, 1) '= "2"` after every `DispatchRequest(PUT)` call and return an error if non-2xx:

```objectscript
Do tService.DispatchRequest(tReqPut, .tRespPut)
If $EXTRACT(tRespPut.Status, 1) '= "2" {
    Set %response.Status = 400
    Write {"error": ("Failed to update ClaimResponse: " _ tRespPut.Status)}.%ToJSON()
    Quit
}
```

### 3. FHIR Datetime Format Validation

The FHIR `DispatchRequest` PUT silently fails (HTTP 400) when the `valueDateTime` field in the authorizer extension uses an invalid datetime format.

The original code produced:
```objectscript
$ZDateTime($Horolog, 3, 1)  →  "2026-05-31 03:28:12"
```

This format has two problems for FHIR validation:
1. **Space separator** instead of `T` between date and time
2. **No timezone suffix** (`Z` for UTC) required by FHIR `dateTime` regex

FHIR rejects this with a 400 validation error — any DateTime value must match ISO 8601.

### 4. `$Get()` on Dynamic Objects (Cause of `<INVALID CLASS>` Crash)

Using `$Get()` to access a dynamic object property causes an `<INVALID CLASS>` error:

```objectscript
// WRONG: Causes <INVALID CLASS> crash
Set tRequestRef = $Get(tCRJson.request, "")
```

Dynamic objects in ObjectScript (%DynamicObject) do not support `$Get()` — use `$IsObject()` guard instead:

```objectscript
// CORRECT: Use $IsObject() guard
If '$IsObject(tCRJson.request) {
    Write {"status":"success","note":"No associated Claim reference for task resolution"}.%ToJSON()
    Quit
}
Set tRequestRef = tCRJson.request.reference
```

## Fix (Complete)

```objectscript
// Use ISO 8601 format for all datetime extensions:
Set tDt = $ZDATE($PIECE($HOROLOG,",",1),3)_"T"_$ZTIME($PIECE($HOROLOG,",",2),1)_"Z"
// Produces: "2026-05-31T03:28:12Z"

// Use sanitized Practitioner reference:
Set tTaskJson.owner = {"reference": "Practitioner/auditor", "display": (tAuthorizedBy)}

// Validate PUT response:
Do tService.DispatchRequest(tReqPut, .tRespPut)
If $EXTRACT(tRespPut.Status, 1) '= "2" {
    Set %response.Status = 400
    Write {"error": ("Failed to update ClaimResponse: " _ tRespPut.Status)}.%ToJSON()
    Quit
}

// Safe request.reference access:
If $IsObject(tCRJson.request) {
    Set tClaimId = $Piece(tCRJson.request.reference, "/", 2)
}
```

## Affected Files
- `src/cls/ClaimAudit/REST/Router.cls` — `ApproveClaim()`, `RejectClaim()`, `EscalateClaim()`, XData UrlMap

## Verification
```bash
# 1. Login
TOKEN=$(curl -s -X POST http://localhost:52773/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"grant_type":"password","username":"admin","password":"ClaimAuditAdmin2026!","client_id":"claimaudit-ui"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# 2. Seed sample data
curl -s -X POST http://localhost:52773/api/samples/load \
  -H "Authorization: Bearer $TOKEN"

# 3. Approve a held claim (should NOT return 404)
CLAIM_ID=$(curl -s "http://localhost:52773/api/claims/held?limit=1" \
  -H "Authorization: Bearer $TOKEN" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['id'])")
curl -s -X POST "http://localhost:52773/api/claims/$CLAIM_ID/approve" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"note":"Valid clinical necessity.","authorizedBy":"Admin"}'

# Expected: {"status":"success","authorizedBy":"Admin"}
# The held count should decrease by 1, and the ledger should show an approved entry.
```

## See Also
[[Security Users Validate Crash]] · [[Rejected Claims Missing From Ledger]] · [[Dashboard Metrics Stale After Actions]]

