# ClaimResponse FHIR Validation

> The FHIR server rejects ClaimResponse resources with `400 Bad Request` when the `total` field uses the wrong schema. ClaimResponse.total is NOT a simple Money type — it is an array of BackboneElement objects.

### Symptom
- Creating a ClaimResponse via FHIR POST returns `400 Bad Request`
- Error body: `"The property name 'value' is not valid for type 'ClaimResponse.total'"`
- Error body: `"The property name 'currency' is not valid for type 'ClaimResponse.total'"`
- ClaimResponse creation succeeds when `total` is omitted entirely

### Root Cause

The FHIR R4 specification defines `ClaimResponse.total` differently from `Claim.total`:

| Resource | Field | Type | Structure |
|----------|-------|------|-----------|
| `Claim` | `total` | `Money` (object) | `{"value": 2500.00, "currency": "USD"}` |
| `ClaimResponse` | `total` | `BackboneElement[]` (array) | `[{"category": {...}, "amount": {"value": 2500.00, "currency": "USD"}}]` |

Using the `Claim.total` structure for `ClaimResponse.total` causes validation errors because the FHIR server expects an **array of objects**, each with a `category` (CodeableConcept) and `amount` (Money).

### Resolution

Use the correct ClaimResponse.total format:

```json
{
  "total": [
    {
      "category": {
        "coding": [
          {
            "system": "http://terminology.hl7.org/CodeSystem/adjudication",
            "code": "submitted"
          }
        ]
      },
      "amount": {
        "value": 2500.00,
        "currency": "USD"
      }
    }
  ]
}
```

#### In ObjectScript (Interactions.cls)

```objectscript
If $IsObject(claimJson.total) {
    Set tTotalObj = {
        "category": {"coding": [{"system": "http://terminology.hl7.org/CodeSystem/adjudication", "code": "submitted"}]},
        "amount": (claimJson.total)
    }
    Set claimResponse.total = [tTotalObj]
}
```

#### In Python / REST API calls

```python
cr = {
    "resourceType": "ClaimResponse",
    # ... other fields ...
    "total": [{
        "category": {
            "coding": [{
                "system": "http://terminology.hl7.org/CodeSystem/adjudication",
                "code": "submitted"
            }]
        },
        "amount": {"value": c["amount"], "currency": "USD"}
    }]
}
```

### Reading the Total Back

When reading the amount back from a ClaimResponse, access it at `total[0].amount.value`:

```objectscript
If $IsObject(tRespCR.Json.total) && (tRespCR.Json.total.%Size() > 0) {
    Set tTotalItem = tRespCR.Json.total.%Get(0)
    If $IsObject(tTotalItem.amount) {
        Set tBilledAmount = +tTotalItem.amount.value
    }
}
```

## See Also
[[Claim Amounts Always $0]] · [[Seed Data Disposition Validation]] · [[FHIR Resource Lifecycle]]
