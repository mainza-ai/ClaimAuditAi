# What is ClaimAuditAI

> ClaimAuditAI is a real-time, database-native payment integrity agent that intercepts FHIR claim submissions pre-commit and uses clinical text vector search, statistical machine learning, and network analytics to dynamically reject or pend high-risk claims.

ClaimAuditAI integrates natively within the transaction loop of the **InterSystems IRIS for Health** database kernel. By utilizing a custom interactions strategy, it intercepts FHIR `Claim` payloads, inspects unstructured clinical text, profiles financial outliers, and checks referral collusion rings before the database commits the transaction.

If a claim is adjudicated as anomalous, the platform dynamically mutates the outgoing HTTP response to a `202 Accepted` hold status. It automatically persists three operational audit trail resources (`ClaimResponse`, `Task`, and `CommunicationRequest`) directly inside the database, bypassing the slow, retrospective "pay-and-chase" workflows of legacy claims auditing systems.

## Key Details
- **Operational Platform**: Built on InterSystems IRIS for Health's FHIR Server.
- **AI Core**: Driven by a multi-agent `%AI.Agent` orchestrator via InterSystems AI Hub.
- **Interception Hooks**: Pre-commit execution inside the `OnBeforeRequest` and `OnAfterRequest` strategy methods.
- **Audit Mutation**: Mutates responses to `202 Accepted` holding dynamic Markdown rationales.

## See Also
[[Problem Statement]] · [[Paradigm Shift - Reactive to Real-Time]] · [[System Architecture Overview]]