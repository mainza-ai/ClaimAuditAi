# Data Flow

> The operational data flow maps how an incoming claim transaction is intercepted, analyzed by the three-tiered AI engine, and mutated into a pended hold.

The lifecycle of an adjudication transaction proceeds in a synchronous sequence inside the InterSystems IRIS FHIR server:

```
[FHIR POST] ──> OnBeforeRequest ──> AuditClaim() ──> [If flagged] ──> GenerateHoldSummary() (LLM)
                                                                            |
[HTTP 202] <── Mutate Response <── OnAfterRequest <── Create Tasks <--------+
```

1. **Payload Ingestion**: The provider POSTs an institutional/professional FHIR `Claim` to the endpoint `/fhir/r4/Claim`.
2. **Interception**: `OnBeforeRequest()` triggers `##class(ClaimAudit.AI.Engine).AuditClaim()`.
3. **Execution**: The engine runs the three analytical tiers. If the threat score exceeds the safety threshold ($\ge 0.35$), the process sets a thread-safe private flag `^||ClaimAuditFlag`.
4. **Summary Generation**: `%AI.Agent` generates an explainable markdown hold summary.
5. **Mutation**: `OnAfterRequest()` reads `^||ClaimAuditFlag`, dispatches three secondary resource creation payloads (`ClaimResponse`, `Task`, `CommunicationRequest`), and mutates the outgoing HTTP response status to `202 Accepted`.

## Key Details
- **Evaluation Status**: Sync execution inside the active REST request thread.
- **Flag Storage**: Stored in process-private global `^||ClaimAuditFlag` to prevent multi-threading resource leaks.
- **Secondary Dispatch**: Runs internally using `pFHIRService.DispatchRequest()` to guarantee ACID transactional consistency.
- **Adjudication Latency**: Typically ranges from 150ms to 400ms under standard transaction volumes.

## See Also
[[FHIR Interception Strategy]] · [[RequestContext vs InteractionsContext]] · [[Three-Tier AI Engine Overview]]