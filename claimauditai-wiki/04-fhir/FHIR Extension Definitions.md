# FHIR Extension Definitions

> Custom FHIR R4 extensions used in ClaimAuditAI `ClaimResponse` resources, carrying audit scores, tier results, and adjudication metadata.

All custom extensions use the base URL `https://claimauditai.com/fhir/extension/` and are attached to the `ClaimResponse` resource during FHIR interception.

## Extension Registry

### Risk Score

| Field | Value |
|-------|-------|
| **URL** | `https://claimauditai.com/fhir/extension/risk-score` |
| **Value Type** | `decimal` |
| **Description** | Combined threat score (0.0–1.0) synthesized from all three tiers |
| **Formula** | `T1 × 0.35 + T2 × 0.35 + T3 × 0.30` (capped at 1.0) |
| **Threshold** | $\ge 0.35$ triggers a hold |

### CPT Code

| Field | Value |
|-------|-------|
| **URL** | `https://claimauditai.com/fhir/extension/cpt-code` |
| **Value Type** | `string` |
| **Description** | Billed CPT procedure code extracted from the claim |

### ICD Code

| Field | Value |
|-------|-------|
| **URL** | `https://claimauditai.com/fhir/extension/icd-code` |
| **Value Type** | `string` |
| **Description** | Primary ICD-10 diagnosis code extracted from the claim |

### Tier Results

| Field | Value |
|-------|-------|
| **URL** | `https://claimauditai.com/fhir/extension/tier-results` |
| **Value Type** | `string` |
| **Description** | JSON-encoded array of Tier 1/2/3 results with scores, flags, and summaries |
| **Example** | `[{"tier":1,"label":"Semantic Clinical Audit","score":0.82,"flags":["CPT 99214 not found in clinical notes"],"summary":"..."}]` |

### Authorized By

| Field | Value |
|-------|-------|
| **URL** | `https://claimauditai.com/fhir/extension/authorized-by` |
| **Value Type** | `string` |
| **Description** | Username of the specialist/director who authorized the override decision |

### Rationale

| Field | Value |
|-------|-------|
| **URL** | `https://claimauditai.com/fhir/extension/rationale` |
| **Value Type** | `string` |
| **Description** | Auditor-entered reason for approve/escalate/reject decision |

### Decision Timestamp

| Field | Value |
|-------|-------|
| **URL** | `https://claimauditai.com/fhir/extension/decision-timestamp` |
| **Value Type** | `string` |
| **Description** | ISO 8601 timestamp of the override decision |

### Provider NPI

| Field | Value |
|-------|-------|
| **URL** | `https://claimauditai.com/fhir/extension/provider-npi` |
| **Value Type** | `string` |
| **Description** | Billing provider's National Provider Identifier |

### Explanation

| Field | Value |
|-------|-------|
| **URL** | `https://claimauditai.com/fhir/extension/explanation` |
| **Value Type** | `string` |
| **Description** | Full LLM-generated adjudication report markdown |

### Workflow Stage

| Field | Value |
|-------|-------|
| **URL** | `https://claimauditai.com/fhir/extension/workflow-stage` |
| **Value Type** | `string` |
| **Description** | Current workflow stage: `"hold"`, `"approved"`, `"escalated"`, `"rejected"` |

### CPT Codes (array)

| Field | Value |
|-------|-------|
| **URL** | `https://claimauditai.com/fhir/extension/cpt-codes` |
| **Value Type** | `string` (comma-separated) |
| **Description** | All CPT codes on the claim |

### ICD Codes (array)

| Field | Value |
|-------|-------|
| **URL** | `https://claimauditai.com/fhir/extension/icd-codes` |
| **Value Type** | `string` (comma-separated) |
| **Description** | All ICD-10 codes on the claim |

## Usage in ClaimResponse

```json
{
  "resourceType": "ClaimResponse",
  "extension": [
    {
      "url": "https://claimauditai.com/fhir/extension/risk-score",
      "valueDecimal": 0.72
    },
    {
      "url": "https://claimauditai.com/fhir/extension/tier-results",
      "valueString": "[{\"tier\":1,\"score\":0.82,\"flags\":[...]},...]"
    },
    {
      "url": "https://claimauditai.com/fhir/extension/workflow-stage",
      "valueString": "hold"
    }
  ],
  "outcome": "partial",
  "disposition": "Pended for AI Audit Review"
}
```

## See Also

[[FHIR Resource Reference Table]] · [[System Architecture Overview]] · [[API Endpoints]]
