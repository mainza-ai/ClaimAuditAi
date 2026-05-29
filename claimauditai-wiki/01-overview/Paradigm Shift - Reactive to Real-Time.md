# Paradigm Shift - Reactive to Real-Time

> ClaimAuditAI transitions claims auditing from retrospective, post-payment recoupment to real-time, pre-commit payment integrity enforcement.

Traditional claims processing pipelines use a decoupled structure where transaction logging is separate from clinical audit verification. ClaimAuditAI changes this by embedding advanced multi-tiered machine learning directly inside the database's transactional commit boundary.

```
Reactive (Legacy):   POST Claim ──> Write to DB ──> Disburse Funds ──> [15 Months] ──> Retrospective Audit ──> Recover (Chase)
Real-Time (Modern):  POST Claim ──> Hook Interceptor ──> Run 3-Tier AI ──> Mutate 202 HOLD & Persist Task ──> Halt Disbursement
```

> [!tip]
> Embedding vector search and statistical models directly inside the FHIR gateway ensures payment integrity checks complete in milliseconds, stopping fraudulent disbursements *before* cash leaves the payer.

## Key Details
- **Interception Level**: Natively bound to the database transaction pre-commit sequence.
- **Operational Latency**: Sub-second end-to-end evaluation including PyTorch and vector lookups.
- **Prevention Hook**: Replaces retrospective recovery files with instant `202 Accepted` pended responses.
- **Audit Automation**: Automatically creates `Task` and `CommunicationRequest` resources for immediate human triage.

## See Also
[[What is ClaimAuditAI]] · [[FHIR Interception Strategy]] · [[Three-Tier AI Engine Overview]]