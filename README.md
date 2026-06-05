# ClaimAuditAI

An autonomous, pre-payment payment integrity agent running natively on InterSystems IRIS for Health. ClaimAuditAI intercepts FHIR Claim submissions in the request lifecycle, analyzes them through a three-tier AI reasoning engine, and holds suspicious transactions for human review.

**Author:** Mainza Kangombe — [LinkedIn](https://www.linkedin.com/in/mainza-kangombe-6214295/)

---

## 🌟 Key Capabilities

- **Real-Time FHIR Interception:** Claims are audited, pended, and held at the database/middleware layer before persistence, fully supporting both single Claims and batch/transaction Bundles.
- **Three-Tier AI Engine:** Runs HNSW clinical note NLP vector search, PyTorch reconstruction loss anomaly profiling, and NetworkX collusion cycle graph analysis sequentially under strict timeout and circuit-breaker safeguards.
- **Atomic Transaction Integrity:** Native FHIR transaction Bundles create hold `ClaimResponse` records, review `Task` resources, and provider `CommunicationRequest` notifications atomically.
- **Federated Security & Role Hierarchy:** Authenticates via SMART on FHIR HS256 JWT tokens, validated against HMAC credential hashes stored in INTEROP globals — no `%SYS` namespace access required. Supports Keycloak RS256 JWKS for federated OIDC. Numeric role hierarchy (Viewer→Auditor→Specialist→Director→Admin) gates all protected endpoints.
- **Persistent Chat History:** Persists LLM assistant auditor conversation histories natively in IRIS via custom `ChatHistory` tables. Provider-agnostic LLM routing supports NVIDIA, Ollama, and OpenAI backends (openai==2.41.0, httpx>=0.28.1). SSE streaming with 300s nginx timeout.
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
- **Tier 1 (NLP Similarity):** Cosine similarity between claim descriptions and progress notes via sentence-transformers in [nlp_auditor.py](src/python/nlp_auditor.py). Flags when best_similarity < 0.38 — CPT codes semantically distant from clinical documentation.
- **Tier 2 (ML Autoencoder Anomaly):** [autoencoder_train.py](src/python/autoencoder_train.py) trains an unsupervised PyTorch Autoencoder (5 input dimensions → 4 bottleneck). Reconstruction loss threshold is `max(95th_percentile, 0.02)` — the 0.02 floor prevents false negatives with homogeneous training data. Requires ≥5 training claims; tier gracefully bypasses (not-flagged) when data is insufficient.
- **Tier 3 (Collusion Networks):** [graph_analyzer.py](src/python/graph_analyzer.py) builds a MultiDiGraph of patient-provider relationships. Detects address collisions, geo-temporal leaps, and referral ring cycles. Graph cache is invalidated after each claim audit. Exception handler is fail-open — errors flag the claim for review, never silently suppress.
- **Risk Scoring:** Tier 1 (+0.35) + Tier 2 (+0.35) + Tier 3 (+0.30), capped at 1.0. Score stored as FHIR ClaimResponse extension — the single source of truth read by all endpoints. Classification: ≥0.86→critical, ≥0.50→high, else→medium.

---

## 🔒 Security & RBAC Model

The system enforces strict role-based access control (RBAC) across both API and database layers:

- **SMART on FHIR Authentication:** HS256 JWT tokens are issued against HMAC-SHA256 credential hashes stored in INTEROP-namespace globals (`^ClaimAuditAI("Users",...)`) — avoiding `%SYS` namespace access for CSP gateway requests. Tokens validated with `$SYSTEM.Encryption.HMACSHA(256, ...)` signature verification. Supports Keycloak RS256 JWKS for federated OIDC.
- **Key Caching & Hardening:** JWKS certificates cached locally for 1 hour. `JWT_SECRET` environment variable required in production mode — raises a critical security error if missing.
- **Role Hierarchy Gatekeeper:** The [Auth.cls](src/cls/ClaimAudit/REST/Auth.cls) middleware extracts roles from the JWT token and enforces a numeric hierarchy (Viewer=1, Auditor=2, Specialist=3, Director=4, Admin=5) on all protected endpoints. Roles read from INTEROP globals — no `$Roles` dependency on IRIS process identity.
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
    # Edit .env: set LLM_PROVIDER (ollama/nvidia/openai), API keys, and JWT_SECRET
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
| `GET` | `/api/stats/model-performance` | Protected | AI model precision/recall/F1 metrics |
| `POST` | `/api/chat` | Protected | AI audit assistant (provider-agnostic LLM) |
| `POST` | `/api/chat/stream` | Protected | SSE streaming chat response |
| `GET/POST`| `/api/settings/llm` | Admin | Query or update runtime LLM provider settings |
| `POST` | `/api/samples/load` | Admin | Clears tables and re-seeds synthetic FHIR data (8 claims with diversified risk) |

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

### 3. Real-World End-to-End Integration Tests (Host to Docker)
To verify the complete payment integrity workflow against the live, dockerized application services from the host, execute the E2E script:
```bash
# From the project root on the host machine
.venv/bin/python scratch/real_world_e2e_tests.py
```
This automated script executes a full transaction verification suite:
* **Persona Authentication:** Logs in as Admin, Auditor, and Director using SMART on FHIR tokens.
* **Auto-healing User Registration:** Dynamically seeds missing roles (`director`, `specialist`) via the Admin API.
* **Fast Database Purge & Seed:** Resets all FHIR tables and seeds the 8 anomalous claims (using the `Seeding` LLM bypass to prevent HTTP connection timeouts).
* **Autoencoder Training:** Triggers the PyTorch autoencoder model retraining on the fresh projections.
* **JIT Adjudication Reports:** Queries the detail page of a held claim, which dynamically triggers the LLM on-demand (JIT) to generate a detailed explainable report and persists it to the database.
* **Auditor Escalation & Director Approval:** Escalates a pended claim to Director review and overrides/approves it.
* **Collusion Graph Insights:** Verifies the NetworkX-generated collusion graph and address-collision detection.
* **Health & Logs Diagnostic:** Audits the component health status and checks admin log entries.
* **FHIR Repository Backup:** Downloads a full backup bundle of the FHIR repository.

### 4. End-to-End Browser Tests (`Playwright`)
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
