# FHIR Resource Lifecycle

> The FHIR resource lifecycle controls how incoming claims are validated, audited, mutated, and saved to the database.

Every transaction processed by the FHIR server undergoes strict validation against the HL7 FHIR R4 schema specifications:

```
REST Client ──> Parse/Validate (R4) ──> Interceptor OnBeforeRequest ──> Save Claim
                                                                           |
REST Client <── Mutate HTTP 202 <── Interceptor OnAfterRequest <── Create Task/CR
```

1. **Submission**: The client POSTs a FHIR resource to the endpoint.
2. **Ingestion Validation**: The engine rejects payloads missing required elements (e.g. `insurance` or `priority` in a `Claim`) with a `400 Bad Request` OperationOutcome.
3. **Audit Lifecycle**: If the resource is valid, the interceptor triggers our payment integrity checks.
4. **Post-Commit Hook**: If flagged, the interceptor creates secondary resources and mutates the HTTP response to `202 Accepted` before returning it.

## Key Details
- **Resource Standard**: HL7 FHIR R4 JSON.
- **Required Claim Fields**: `insurance` (Coverage Reference), `priority` (CodeableConcept).
- **Secondary Resource Status**: Stored with status `"active"` (for `ClaimResponse` and `CommunicationRequest`) and `"ready"` (for `Task`).
- **Audit Logging**: Successful creations write record IDs to the `%SYS` global logging tables.

## See Also
[[FHIR Interception Strategy]] · [[OperationOutcome Structure]] · [[FHIR Resource Reference Table]]