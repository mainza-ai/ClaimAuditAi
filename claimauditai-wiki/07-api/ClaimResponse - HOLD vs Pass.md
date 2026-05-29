# ClaimResponse - HOLD vs Pass

> The FHIR ClaimResponse resource payload differs significantly depending on whether the claim passes the AI engines or is held as anomalous.

The adjudication engine evaluates claims pre-payment and routes them to one of two operational outcomes:

### 1. Adjudication PASS (HTTP 201 Created)
If the claim is low-risk, it is written to the database normally. The system returns an HTTP `201 Created` status with standard FHIR billing parameters.

### 2. Adjudication HOLD (HTTP 202 Accepted)
If the claim is flagged as anomalous, the system intercepts the transaction, pends the payment, and returns an HTTP `202 Accepted` status. The response body is mutated to a pended `ClaimResponse` containing:
- `"outcome": "queued"`
- `"disposition"`: The explainable markdown audit report authored by the LLM.

## Key Details
- **Pass Status Code**: `201 Created` (Claim accepted and disbursed).
- **Hold Status Code**: `202 Accepted` (Claim held and queued for review).
- **Hold Outcome Field**: `"outcome": "queued"`
- **Markdown Rationale Path**: Exposed inside the `disposition` property of the mutated JSON payload.

## See Also
[[Endpoint Reference]] · [[OperationOutcome Structure]] · [[FHIR Resource Reference Table]]