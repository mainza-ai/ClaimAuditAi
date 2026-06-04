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
                  |    %AI.Agent Synthesis Orchestrator|
                  +-----------------------------------+
```

- **Tier 1 (Semantic NLP)**: Cross-references billed CPT procedures against raw progress notes using sentence embeddings and `VECTOR_COSINE`.
- **Tier 2 (Statistical Outlier)**: Detects financial manipulation and billing anomalies using reconstruction loss scores.
- **Tier 3 (Relational Collusion)**: Identifies provider fraud rings and referral loops using graph analytics.

## Key Details
- **Cooperation Protocol**: The tiers execute concurrently inside the Embedded Python environment.
- **Score Synthesis**: The outcomes of all three tiers are combined into a standardized anomaly object. Tier 1 (NLP) contributes +0.35, Tier 2 (Autoencoder) +0.35, Tier 3 (Graph) +0.30, capped at 1.0. The score is stored as a FHIR ClaimResponse extension (`risk-score`) — the single source of truth read by all endpoints.
- **Default Action Limit**: Any single-tier failure or a combined threat score $\ge 0.35$ triggers a hold status.
- **Risk Classification**: Unified across all endpoints using numeric thresholds on the stored risk-score extension: $\ge 0.86$ = critical, $\ge 0.50$ = high, else = medium. Disposition text matching is no longer used.
- **Local Verification**: Supports offline evaluation via local CPU PyTorch execution and sentence transformers.

## See Also
[[Tier 1 - Semantic Clinical Auditor]] · [[Tier 2 - Statistical Outlier Profiler]] · [[Tier 3 - Collusion Network Mapper]] · [[Orchestration - AI Hub]]