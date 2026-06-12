# Three-Tier AI Engine Overview

> The ClaimAuditAI payment integrity framework utilizes a multi-tiered diagnostic system to analyze claims across semantic, statistical, and relational vectors.

By combining three distinct analytical engines, the platform identifies fraudulent patterns that rule-based systems miss:

```
                  +-----------------------------------+
                  |          Incoming Claim           |
                  +-----------------------------------+
                                    |
            +-----------------------+-----------------------+
            |                       |                       |
            v                       v                       v
+-----------------------+ +-----------------------+ +-----------------------+
|  Tier 1: Semantic NLP | |  Tier 2: PyTorch ML   | |  Tier 3: NetworkX     |
|   Vector Similarity   | |     Autoencoder       | |   Relational Graph    |
| (Check Notes vs CPT)  | |  (Check Financials)   | |  (Check Referral)   |
+-----------------------+ +-----------------------+ +-----------------------+
            |                       |                       |
            +-----------------------+-----------------------+
                                    |
                                    v
                  +-----------------------------------+
                  |     Pydantic Graph FSM & Agent    |
                  +-----------------------------------+
```

- **Tier 1 (Semantic NLP)**: Cross-references billed CPT procedures against raw progress notes using sentence embeddings and `VECTOR_COSINE`.
- **Tier 2 (Statistical Outlier)**: Detects financial manipulation and billing anomalies using reconstruction loss scores.
- **Tier 3 (Relational Collusion)**: Identifies provider fraud rings and referral loops using graph analytics.

## Key Details
- **Cooperation Protocol**: The tiers execute sequentially as structured nodes (`ClinicalAuditNode`, `AnomalyAuditNode`, `NetworkAuditNode`) in a compiled Pydantic Graph FSM to guarantee type safety and prevent database context collisions.
- **Score Synthesis**: The outcomes of all three tiers are combined into a standardized anomaly object. Tier 1 (NLP) contributes +0.35, Tier 2 (Autoencoder) +0.35, Tier 3 (Graph) +0.30, capped at 1.0. The score is stored as a FHIR ClaimResponse extension (`risk-score`) — the single source of truth read by all endpoints.
- **Default Action Limit**: Any single-tier failure or a combined threat score $\ge 0.35$ triggers a hold status.
- **Risk Classification**: Unified across all endpoints using numeric thresholds on the stored risk-score extension: $\ge 0.86$ = critical, $\ge 0.50$ = high, else = medium. Disposition text matching is no longer used.
- **Local Verification**: Supports offline evaluation via local CPU PyTorch execution and sentence transformers.

## Additional Python Modules

The AI engine layer also includes:

| Module | Purpose |
|--------|---------|
| `tier_orchestrator.py` | Sequential tier execution with per-tier timeouts (180s/120s/120s) and circuit breaker (3 failures → 60s cooldown) |
| `agent_tools.py` | Tool registry for the ReAct agent loop — wraps `nlp_auditor`, `autoencoder_train`, `graph_analyzer`, and `dx_procedure_validator` as callable tools |
| `dx_procedure_validator.py` | Diagnosis-Procedure (ICD–CPT) compatibility validation — checks if the billed procedure is medically justified by the diagnosis |
| `mcp_server.py` | FastMCP terminology server — exposes `lookup_cpt_code`, `lookup_icd_code`, and `validate_codes` as MCP tools |

## See Also
[[Tier 1 - Semantic Clinical Auditor]] · [[Tier 2 - Statistical Outlier Profiler]] · [[Tier 3 - Collusion Network Mapper]] · [[Orchestration - AI Hub]] · [[LLM Router Architecture]] · [[Agent Tool Registry]] · [[Diagnosis-Procedure Validator]]