# FHIR Resource Reference Table

> The FHIR Resource Reference Table maps the primary and auxiliary FHIR resources used within the ClaimAuditAI ecosystem.

| Resource Type | Workflow Role | Key Elements Verified/Generated | Primary Linkage |
| :--- | :--- | :--- | :--- |
| **Claim** | Ingested Adjudication Target | `patient` reference, `provider` reference, `item.productOrService` (CPT), `total` | Entry request payload |
| **DocumentReference** | Source Clinical Truth | `subject` patient link, `content.attachment.data` (Base64 Progress Notes) | Ingested patient clinical history |
| **ClaimResponse** | Adjudication Hold Artifact | `outcome` (`queued`), `disposition` (Markdown explanation), `request` (Claim link) | Mutated response payload |
| **Task** | Manual Audit Route | `status` (`ready`), `intent` (`order`), `priority` (`urgent`), `focus` (Claim link), `owner` | Internal review queues |
| **CommunicationRequest** | Hold Notification | `status` (`active`), `payload.contentString`, `about` (Claim & ClaimResponse links) | Provider notification channels |

## Key Details
- **FHIR Version Compatibility**: HL7 FHIR R4 JSON.
- **State Mutation**: Intercepted claims mutate from standard `POST` outcomes to `202 Accepted` holds.
- **Reference Integrity**: Programmatically created resources maintain strict internal reference mappings using the generated database IDs.

## See Also
[[FHIR Resource Lifecycle]] · [[Endpoint Reference]] · [[ClaimResponse - HOLD vs Pass]]