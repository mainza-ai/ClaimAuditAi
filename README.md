# ClaimAuditAI

An autonomous, pre-payment payment integrity agent running natively on InterSystems IRIS for Health. ClaimAuditAI intercepts FHIR Claim submissions in the request lifecycle, analyzes them through a three-tier AI reasoning engine, and holds suspicious transactions for human review.

**Author:** Mainza Kangombe — [LinkedIn](https://www.linkedin.com/in/mainza-kangombe-6214295/)

---

## 🌟 Key Capabilities

- **Real-Time FHIR Interception:** Claims are audited, pended, and held at the database/middleware layer before persistence.
- **Three-Tier Parallel AI Engine:** Executes NLP vector search, PyTorch reconstruction loss, and NetworkX collusion graph analysis concurrently under strict timeout safeguards.
- **Atomic Transaction Integrity:** Native FHIR transaction Bundles create pended `ClaimResponse`, manual audit `Task`, and provider `CommunicationRequest` resources atomically.
- **Role-Based Adjudication:** SMART on FHIR token verification gates system actions across Auditor, Specialist, Director, and Admin views.
- **Tamper-Proof Audit Ledger:** Timestamped, high-precision subscript records provide a reliable audit trail of all override decisions.
- **Interactive Collusion Graphs:** Visualizes provider-patient networks dynamically using Cytoscape.js to identify billing syndicates.

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
│  (Parallel Thread Executor)  │
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
The [Interactions.cls](src/cls/ClaimAudit/FHIR/Interactions.cls) class intercepts incoming POST/PUT requests on the `Claim` resource type. If a claim is flagged as an anomaly by the AI engines:
1. The interceptor blocks the standard claim response.
2. It constructs a FHIR `transaction` Bundle to atomically write:
   - A `ClaimResponse` with `outcome` set to `queued` (Hold status), enriched with risk score and billing code extensions.
   - A `Task` routed to the manual auditor queues.
   - A `CommunicationRequest` containing the claim hold reason.
3. The server responds with `202 Accepted`, informing the provider that the claim is held pending review.

### 2. The 3-Tier AI Engine (`tier_orchestrator.py`)
AI evaluation runs within the database memory space using Embedded Python, managed by a parallel ThreadPoolExecutor with individual timeout safeguards and circuit breaker states:
- **Tier 1 (NLP Similarity):** Vectors are extracted from clinical progress notes stored in the native IRIS HNSW index. [nlp_auditor.py](src/python/nlp_auditor.py) compares claim billing descriptions against clinical records using cosine similarity.
- **Tier 2 (ML Autoencoder Anomaly):** [autoencoder_train.py](src/python/autoencoder_train.py) feeds patient age, billed amount, service duration, specialty, and item counts into a PyTorch autoencoder. High reconstruction loss flags outlier billing patterns.
- **Tier 3 (Collusion Networks):** [graph_analyzer.py](src/python/graph_analyzer.py) builds a directed multigraph of patient-provider networks using NetworkX. It detects geo-temporal leap loops, address collisions, and syndicate cycles.

---

## 🔒 Security & RBAC Model

The system enforces strict role-based access control (RBAC) across both API and database layers:

- **JWT Authentication:** Smart on FHIR standard tokens are issued via HS256 JWT signature generation (`$SYSTEM.Encryption.HMACSHA256`).
- **Endpoint Protection:** The [Auth.cls](src/cls/ClaimAudit/REST/Auth.cls) middleware extracts user roles from the JWT context and gates access:
  - **Auditor / Specialist:** Review holds, escalate claims, and view dashboards.
  - **Director:** Override approvals, review escalated holds, and write to the audit ledger.
  - **Tech Owner / Admin:** Wipe data, load sample bundles, and update LLM runtime configurations.
- **IRIS Application Hardening:** Web applications (`/api` and `/csp/interop`) run under least privilege matching roles (`:%DB_INTEROP-CODE:%DB_INTEROP-DATA:%Admin_Secure`) instead of matched `%All` privilege.

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
