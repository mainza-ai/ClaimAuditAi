# Orchestration - AI Hub

> The AI Hub orchestrates payment integrity decisions by combining our three machine learning engines with LLM synthesis models.

ClaimAuditAI utilizes the native InterSystems AI Hub classes (`%AI.Agent`, `%AI.ToolSet`, `%AI.Tool`) to configure its cognitive pipeline. The multi-agent orchestrator aggregates threat scores from our three AI engines:

```objectscript
// Retrieve threat details and synthesize using AI Agent
Set summary = ##class(ClaimAudit.AI.Agent).GenerateHoldSummary(
    tAuditResult.patientId, tAuditResult.providerNpi, 
    tAuditResult.billedAmount, tAuditResult.codeCount, 
    tAuditResult.serviceDate, tAuditResult.firstCodeDesc, 
    tAuditResult.reasons
)
```

If the combined threat score is $\ge 0.35$ (or if any single-tier engine flags an anomaly), the orchestrator triggers a hold. It instructs the `%AI.Agent` to author a detailed, explainable markdown hold justification report for the clinical audit queue.

### Just-In-Time (JIT) Generation & Seeding Bypass
Because generating detailed LLM summaries synchronously can take 10-25 seconds and lead to HTTP gateway connection timeouts (e.g. 504 Gateway Timeout) during bulk ingestion or database seeding:
1. **Seeding Bypass:** A process-level `^ClaimAuditAI("Seeding")` flag is enabled during bulk sample loading (`/api/samples/load`). The FHIR interceptor skips the slow LLM generation calls for seeded anomalous claims, storing only the basic reason strings. This cuts database loading down from 100+ seconds to under 2 seconds.
2. **On-Demand (JIT) Compilation:** When an auditor or E2E script opens the detail page for a pended claim (`GET /api/claims/:id`), the server detects the basic hold summary and invokes `GenerateHoldSummary` on-demand (just-in-time). The fully synthesized LLM report is then updated on the `ClaimResponse` resource (`PUT`) and cached in the database for subsequent instant loads.

## Key Details
- **Core Orchestrator**: `%AI.Agent` configured via high-performance cloud or local LLM gateways.
- **Tool Mapping**: `%AI.Tool` bindings representing vector similarity, outlier analysis, and graph checks.
- **Score Synthesis**: Tier 1 (NLP) +0.35, Tier 2 (Autoencoder) +0.35, Tier 3 (Graph) +0.30, capped at 1.0. Score stored as FHIR ClaimResponse extension.
- **Threshold Limit**: Combined threat score $\ge 0.35$ triggers a hold status.
- **Language Models**: Provider-agnostic routing via `llm_router.py` — supports `nvidia`, `ollama`, and `openai` backends. Uses `openai==2.41.0` library with `httpx>=0.28.1`. RETRY_COUNT=3 with exponential backoff; rate-limit check inside retry loop.

## See Also
[[Three-Tier AI Engine Overview]] · [[ClaimResponse - HOLD vs Pass]] · [[VECTOR_COSINE Query Pattern]]