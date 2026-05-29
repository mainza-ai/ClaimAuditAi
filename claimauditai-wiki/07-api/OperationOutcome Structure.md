# OperationOutcome Structure

> The OperationOutcome resource contains detailed validation error summaries when an ingested payload fails the FHIR schema constraints.

Before our payment integrity engines evaluate a claim, the InterSystems FHIR server validates the JSON payload against standard FHIR R4 schema constraints. If validation fails, the transaction is halted, and the server returns a `400 Bad Request` containing an `OperationOutcome` resource:

```json
{
  "resourceType": "OperationOutcome",
  "issue": [
    {
      "severity": "error",
      "code": "invalid",
      "diagnostics": "<HSFHIRErr>MissingRequiredProperty",
      "details": {
        "text": "The type 'Claim' requires a property named 'insurance'"
      }
    }
  ]
}
```

Common validation errors include missing required properties (such as `insurance` or `priority`) or malformed strings containing emojis that violate the strictly enforced `[
	 -￿]*` character pattern.

## Key Details
- **Status Code**: `400 Bad Request`
- **Resource Type**: `OperationOutcome`
- **Strict Regex Check**: `[
	 -￿]*` (Emojis violate this constraint, triggering a schema exception).
- **Common Diagnostics**: `<HSFHIRErr>MissingRequiredProperty`

## See Also
[[FHIR Resource Lifecycle]] · [[Endpoint Reference]] · [[Container Startup Failures]]