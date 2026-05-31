# Claim Amounts Always $0

> Claim `totalAmount` displays as `$0` in the UI even though the sample claims have real dollar values (e.g., $2,500). The root cause is that the FHIR interceptor never persists the original Claim resource — only the ClaimResponse (hold) is saved.

### Symptom
- All claims in the Hold Queue show `$0.00` as the billed amount
- `GET /api/stats` returns `"totalValueHeld": 0`
- The claim list shows correct patient names and CPT codes, but `totalAmount` is always 0

### Root Cause

The FHIR interceptor (`Interactions.cls::OnAfterRequest`) intercepts incoming Claim POST requests, evaluates them through the three-tier AI pipeline, and creates a **ClaimResponse** resource to hold the claim. However, due to the interceptor pattern, the **original Claim resource is never persisted** in the FHIR repository:

```
Client POST /Claim  →  FHIR Server saves Claim  →  OnAfterRequest runs
                                                      ↓
                                              Creates ClaimResponse (hold)
                                              Replaces response with CR
                                              ↑ Original Claim is NOT committed
```

The `GetHeldClaims` and `GetStats` methods in `Router.cls` try to fetch the Claim resource via `GET /Claim/<id>` to read `total.value`, but the Claim doesn't exist in the repository — returning `0` for all amounts.

### Resolution

#### Fix 1: Store the total amount in the ClaimResponse (recommended)

The FHIR `ClaimResponse` resource type has a `total` field that is an **array of BackboneElement** objects (not a plain Money type). Each element has:
- `category`: CodeableConcept describing the total type (e.g., "submitted")
- `amount`: Money object with `value` and `currency`

In `Interactions.cls`, copy the total from the incoming Claim JSON:

```objectscript
// In OnAfterRequest, when building the claimResponse object:
If $IsObject(claimJson.total) {
    Set tTotalObj = {
        "category": {"coding": [{"system": "http://terminology.hl7.org/CodeSystem/adjudication", "code": "submitted"}]},
        "amount": (claimJson.total)
    }
    Set claimResponse.total = [tTotalObj]
}
```

#### Fix 2: Add fallback reads in Router.cls

In `GetHeldClaims`, after the Claim fetch fails (caught by `Try/Catch`), fall back to reading the total from the ClaimResponse itself:

```objectscript
// Fallback: read total from ClaimResponse's own stored JSON
If tBilledAmount = 0 {
    Set tReqCR = ##class(HS.FHIRServer.API.Data.Request).%New()
    Set tReqCR.RequestMethod = "GET"
    Set tReqCR.RequestPath = "/ClaimResponse/" _ tClaimResponseId
    Set tReqCR.Interaction = "read"
    Set tRespCR = ##class(HS.FHIRServer.API.Data.Response).%New()
    Do tService.DispatchRequest(tReqCR, .tRespCR)
    If $IsObject(tRespCR.Json) && $IsObject(tRespCR.Json.total) && (tRespCR.Json.total.%Size() > 0) {
        Set tTotalItem = tRespCR.Json.total.%Get(0)
        If $IsObject(tTotalItem.amount) {
            Set tBilledAmount = +tTotalItem.amount.value
        }
    }
}
```

#### Fix 3: For existing data, rebuild with corrected interceptor

The interceptor fix only helps future claim ingestion. For existing data where ClaimResponses were already created without the `total` field, you must:

1. Rebuild the Docker image with the fixed `Interactions.cls`
2. Wipe and re-seed the data (use the fast seed script at `/tmp/seed_fast.py`)

```bash
docker compose build iris
docker compose up -d
# Wait for IRIS to start, then seed:
docker cp /tmp/seed_fast.py claimaudit-iris:/tmp/seed_fast.py
docker exec claimaudit-iris python3 /tmp/seed_fast.py
```

### Also Affected

The same issue affects `GetStats` (compute `totalValueHeld`) and `GetLedger` (compute `amount`). Both now include fallback logic to read from the ClaimResponse when the Claim fetch fails.

## See Also
[[ClaimResponse FHIR Validation]] · [[Seed Data Disposition Validation]] · [[Seed Data Loading Timeout]]
