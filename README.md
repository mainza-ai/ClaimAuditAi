# ClaimAuditAI

An autonomous, pre-payment payment integrity agent running natively on InterSystems IRIS for Health. ClaimAuditAI intercepts FHIR Claim submissions in the request lifecycle, analyzes them through a three-tier AI reasoning engine, and holds suspicious transactions for human review.

**Author:** Mainza Kangombe — [LinkedIn](https://www.linkedin.com/in/mainza-kangombe-6214295/)

---

## 🌟 Key Capabilities

- **Real-Time FHIR Interception:** Claims are audited, pended, and held at the database/middleware layer before persistence, fully supporting both single Claims and batch/transaction Bundles.
- **Three-Tier AI Engine:** Runs HNSW clinical note NLP vector search, PyTorch reconstruction loss anomaly profiling, and NetworkX collusion cycle graph analysis sequentially under strict timeout and circuit-breaker safeguards.
- **Atomic Transaction Integrity:** Native FHIR transaction Bundles create hold `ClaimResponse` records, review `Task` resources, and provider `CommunicationRequest` notifications atomically.
- **Federated Security & Role Hierarchy:** Authenticates via SMART on FHIR tokens supporting symmetric HS256 local HMAC or asymmetric Keycloak RS256 JWKS validation, backed by public key caching and numeric role-hierarchy access controls.
- **Persistent Chat History:** Persists LLM assistant auditor conversation histories natively in IRIS via custom `ChatHistory` tables.
- **Tamper-Proof Audit Ledger:** High-precision subscript records (`^ClaimAuditLedger`) provide a reliable, date-indexed audit trail of override decisions.
- **Interactive Collusion Graphs:** Visualizes provider-patient networks dynamically using Cytoscape.js to identify billing steering syndicates.

---

## 🏗 System Architecture

ClaimAuditAI integrates InterSystems IRIS for Health with an Embedded Python runtime and a React/TypeScript frontend.

```
       [ Submitted Claim ]
               │
               ▼
┌──────────────────────────────┐
│  InterSystems IRIS FHIR App  │
│  (FHIR Interceptor Hooks)    │
└──────────────┬───────────────┘
               │ (Atomic Transaction Bundle)
               ▼
┌──────────────────────────────┐
│      tier_orchestrator       │
│  (Sequential Engine Runner)   │
└──────┬───────┬───────┬───────┘
       │       │       │
       │       │       └─────────────────────────────┐
       ▼ (Timeout & Circuit Breaker)                 ▼
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│  Tier 1: NLP │       │  Tier 2: ML  │       │Tier 3: Graph │
│ (HNSW Vector │       │ (PyTorch AE  │       │ (NetworkX    │
│  Similarity) │       │ Anomaly Loss)│       │  Collusion)  │
└──────────────┘       └──────────────┘       └──────────────┘
```

### 1. The Interception Hook (`OnBeforeRequest` & `OnAfterRequest`)
The [Interactions.cls](src/cls/ClaimAudit/FHIR/Interactions.cls) class intercepts incoming requests for single `Claim` submissions or batch `Bundle` submissions. If a claim is flagged by the three-tier AI reasoning engine:
1. The interceptor temporarily intercepts standard storage persistence.
2. It aggregates holds and compiles an atomic FHIR `transaction` Bundle to write:
   - A `ClaimResponse` with `outcome` set to `queued` (HOLD status) and custom billing code/threat level extensions.
   - A manual audit `Task` routed to the practitioner queue.
   - A `CommunicationRequest` hold notification.
3. The response payload is mutated to return HTTP `202 Accepted` alongside the created hold `ClaimResponse` resource.

### 2. The 3-Tier AI Engine (`tier_orchestrator.py`)
AI evaluation runs within the database memory space using Embedded Python, running sequentially to ensure thread-safety and database integrity in InterSystems IRIS:
- **Tier 1 (NLP Similarity):** Cosine similarity between claim descriptions and progress notes is evaluated using sentence-transformers vector indexing in [nlp_auditor.py](src/python/nlp_auditor.py).
- **Tier 2 (ML Autoencoder Anomaly):** [autoencoder_train.py](src/python/autoencoder_train.py) trains an unsupervised PyTorch Autoencoder to evaluate claim structures. Categorical specialties are scaled stably without Z-score distortion.
- **Tier 3 (Collusion Networks):** [graph_analyzer.py](src/python/graph_analyzer.py) builds a bipartite patient-provider graph using NetworkX. It maps undirected cycle bases to uncover relational steering rings, address overlaps, and geo-temporal leap impossibilities.

---

## 🔒 Security & RBAC Model

The system enforces strict role-based access control (RBAC) across both API and database layers:

- **SMART on FHIR Authentication:** Supports both HS256 local HMAC signature verification and RS256 JWKS verification for federated OpenID Connect (OIDC) identity providers like Keycloak.
- **Key Caching & Hardening:** JWKS certificates are cached locally for 1 hour to prevent roundtrip API overhead. The environment requires a valid `JWT_SECRET` in production, raising a hard exception if missing.
- **Role Hierarchy Gatekeeper:** The [Auth.cls](src/cls/ClaimAudit/REST/Auth.cls) middleware uses a numeric role hierarchy to authorize access (e.g. Director and Admin roles inherit Auditor and Specialist abilities on API endpoints):
  - **Auditor:** Reviews held claims, escalates anomalies.
  - **Specialist:** Conducts collusion graph analysis, manages second-stage overrides.
  - **Director:** Resolves escalated pended holds (Approve/Reject), authors ledger override summaries.
  - **Tech Owner / Admin:** Full settings administration, model retraining, and system purges.
- **Least-Privilege IRIS Hardening:** Web applications (`/api` and `/interop/fhir/r4`) run under tightened MatchRoles parameters (`:%DB_INTEROP-CODE:%DB_INTEROP-DATA:%Admin_Secure`) instead of matching `%All` permissions.

---

## 🚀 Quick Start (Docker Environment)

### Prerequisites
- Docker & Docker Compose
- A modern browser (Chrome/Firefox/Safari)

### Setup & Run
1. Clone the repository and configure environments:
   ```bash
   git clone https://github.com/mainza-ai/ClaimAuditAi.git
   cd ClaimAuditAi
   cp .env.example .env
   ```
2. Build and launch the containers:
   ```bash
   docker compose up -d --build
   ```
3. Load and seed the extended sample FHIR data bundles:
   ```bash
   docker exec -it claimaudit-iris iris session IRIS "##class(ClaimAudit.REST.Router).LoadSampleData()"
   ```

Open `http://localhost:3000` to access the dashboard.
- **Default Auditor Login:** `auditor` / `AuditReview2026!`
- **Default Admin Login:** `admin` / `ClaimAuditAdmin2026!`

---

## 🔌 REST API Catalog

All protected endpoints require an `Authorization: Bearer <token>` header:

| Method | Path | Access | Purpose |
|:---|:---|:---|:---|
| `POST` | `/api/auth/login` | Public | Authenticates credentials and returns a signed JWT |
| `POST` | `/api/auth/introspect` | Public | SMART on FHIR token validation (RFC 7662) |
| `GET` | `/api/stats` | Protected | Aggregated hold, complete, and value metrics |
| `GET` | `/api/claims/held` | Protected | Paginated active hold queue |
| `GET` | `/api/claims/:id` | Protected | Detailed claim JSON with AI reason summaries |
| `POST` | `/api/claims/:id/approve` | Auditor+ | Approve override (writes to ledger, completes task) |
| `POST` | `/api/claims/:id/reject` | Auditor+ | Reject claim (sets outcome to error, cancels task) |
| `POST` | `/api/claims/:id/escalate` | Auditor+ | Progresses task status (Specialist -> Director) |
| `GET` | `/api/ledger` | Protected | Paginated override audit ledger log |
| `GET` | `/api/graph` | Protected | Cytoscape network graph data |
| `GET/POST`| `/api/settings/llm` | Admin | Query or update runtime LLM provider settings |
| `POST` | `/api/samples/load` | Admin | Clears tables and re-seeds synthetic FHIR data |

---

## 🧪 Testing & Verification

Comprehensive verification suites validate both client and server layers.

### 1. Python Unit Tests (`pytest`)
Contains 23 test cases verifying NLP calculations, PyTorch training/inference anomaly outputs, NetworkX network cycles, and `tier_orchestrator` circuit breakers:
```bash
# Inside the container (or local environment with virtualenv)
pytest src/python/tests/ -v
```

### 2. Frontend Unit & Store Tests (`Vitest`)
Runs 18 test cases checking React components, rendering states, and Zustand stores:
```bash
cd ui
npm run test
```

### 3. End-to-End Tests (`Playwright`)
Simulates user behavior covering login, sidebar routing, sample data seeding, and hold queue approval cycles:
```bash
cd ui
npm run test:e2e
```

### 4. CI/CD Integration
A GitHub Actions workflow ([ci.yml](.github/workflows/ci.yml)) automates quality gates on every push/PR:
- Linters & Types (`eslint`, `tsc --noEmit`)
- Python test suite & Vitest coverage exports
- Production asset compilation verification

---

## 📘 Detailed Documentation
- Visit the [Comprehensive Wiki Pages](claimauditai-wiki/00-index/ClaimAuditAI%20Home.md) for deeper information on ML models, FHIR structures, setup guides, and troubleshooting recipes.

## 📄 License
MIT License
