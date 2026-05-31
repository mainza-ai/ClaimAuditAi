# ClaimAuditAI

Autonomous pre-payment payment integrity agent running natively on InterSystems IRIS for Health.

Developed for the **InterSystems Programming Contest: AI Agents for FHIR**.

**Author:** Mainza Kangombe — [LinkedIn](https://www.linkedin.com/in/mainza-kangombe-6214295/)

---

## Architecture

A three-tier AI reasoning engine executes concurrently within the FHIR transaction lifecycle:

| Tier | Engine | Method |
|------|--------|--------|
| 1 | `nlp_auditor.py` | Semantic NLP vector search via HNSW index |
| 2 | `autoencoder_train.py` | PyTorch autoencoder — 95th percentile reconstruction loss threshold |
| 3 | `graph_analyzer.py` | NetworkX directed graph — address collision, geo-temporal leap, collusion detection |

Flagged claims generate a `ClaimResponse` (held), a `Task`, and a `CommunicationRequest` — all before the claim is persisted.

---

## Quick Start

```bash
git clone https://github.com/mainza-ai/ClaimAuditAi.git
cd claimauditai
cp .env.example .env
docker compose up -d --build
docker exec claimaudit-iris python3 /tmp/seed_fast.py
```

Open `http://localhost:3000`. See the [wiki](claimauditai-wiki/00-index/ClaimAuditAI%20Home.md) for full documentation.

---

## Key Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/api/stats` | Dashboard metrics |
| `GET` | `/api/claims/held` | Held claims queue |
| `GET` | `/api/claims/:id` | Claim detail with AI disposition |
| `POST` | `/api/claims/:id/approve` | Approve (role-gated) |
| `POST` | `/api/claims/:id/reject` | Reject (role-gated) |
| `POST` | `/api/claims/:id/escalate` | Escalate to director |
| `GET` | `/api/ledger` | Audit ledger |
| `GET` | `/api/graph` | Collusion network (Cytoscape.js) |
| `GET/POST` | `/api/settings/llm` | LLM provider config (runtime-switchable) |
| `POST` | `/api/chat` | AI audit assistant |

---

## Features

- Real-time FHIR interception — claims held pre-payment at the middleware layer
- Role-based access: Auditor, Specialist, Director, Tech Owner / Admin
- Interactive collusion network graph with anomaly insights
- AI audit assistant with per-claim context and conversation history
- Light/dark theme with persistence
- Auto-refreshing dashboard with recharts visualizations
- Data management for seeding, uploading, and clearing FHIR test data

---

## Troubleshooting

Common issues and solutions are documented in the [troubleshooting guide](claimauditai-wiki/09-troubleshooting/Troubleshooting%20Overview.md):

| Symptom | Likely Cause |
|---------|-------------|
| Claims stay in hold queue after action | FHIR datetime format rejected by PUT |
| Metrics never update | Missing `refetchInterval` |
| Dashboard shows all zeros | `CAST(_lastUpdated AS DATE)` incompatibility |
| Rejected claims invisible in ledger | `GetLedger` excluded cancelled tasks |
| Admin routes return 401 | IRIS CSP blocks `/admin` path prefix |
| Dark mode doesn't persist | `applyTheme()` not called on store init |

---

## License

MIT
