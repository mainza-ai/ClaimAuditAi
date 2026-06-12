# FHIR Server Provisioning

> The FHIR server configuration provisions the `/fhir/r4` endpoint and registers the custom `ClaimAudit.FHIR.InteractionsStrategy`.

## Architecture

The FHIR server runs in the `INTEROP` namespace. It is provisioned at **Docker build** time by `iris.script`, ensuring the `/fhir/r4` endpoint is fully baked into the compiled container image. The container startup script `init_iris.sh` acts as a runtime fallback to verify or recreate the endpoint if starting with empty mounted volumes:

```
Build-Time Flow:
  iris.script
    │
    ├── Compile FHIR classes (Interactions, InteractionsStrategy, RepoManager)
    │
    ├── InstallNamespace()  ← loads FHIR metadata packages
    │     (hl7.fhir.r3.core, hl7.fhir.r4.core, etc.)
    │
    ├── InstallInstance("/fhir/r4", ...)
    │     │
    │     ├── Creates HSFHIR_X0001_S.* schema tables
    │     │   (Claim, ClaimResponse, Patient, Task, etc.)
    │     │
    │     └── Binds ClaimAudit.FHIR.InteractionsStrategy
    │
    └── Engine.Setup() ← creates custom tables + ML models
```

## Custom Strategy Classes

The default FHIR server storage uses `HS.FHIRServer.Storage.Json.RepoManager`. Our custom classes override this to intercept claim submissions:

| Component | Class | Purpose |
|-----------|-------|---------|
| **Strategy** | `ClaimAudit.FHIR.InteractionsStrategy` | Entry point — routes to custom Interactions |
| **Interactions** | `ClaimAudit.FHIR.Interactions` | Intercepts `OnBeforeRequest`/`OnAfterRequest` to run AI audit |
| **RepoManager** | `ClaimAudit.FHIR.RepoManager` | Binds StrategyClass to our InteractionsStrategy |

## Claim Interception Flow

When a Claim is submitted via POST to `/fhir/r4/Claim`:

```
POST /Claim
    │
    v
OnBeforeRequest ──> ClaimAudit.AI.Engine.AuditClaim()
    │                    │
    │              ┌─────┴─────┐
    │              │ Tier 1    │ NLP Semantic Audit
    │              │ Tier 2    │ Statistical Autoencoder
    │              │ Tier 3    │ Graph Collusion Network
    │              └─────┬─────┘
    │                    v
    │              AuditResult.flagged?
    │              ├── YES: set ^||ClaimAuditFlag("flagged")=1
    │              └── NO:  proceed normally
    │
    v
OnAfterRequest
    │
    ├── If flagged:
    │       ├── Create ClaimResponse (outcome="queued")
    │       ├── Create Task (priority="urgent")
    │       ├── Create CommunicationRequest (hold notification)
    │       └── Return HTTP 202 (Accepted/Queued)
    │
    └── If not flagged:
            └── Return HTTP 201 (Created)
```

## API Endpoints (REST Router)

The `/api` web application at `http://localhost:52773/api/*` is dispatched by `ClaimAudit.REST.Router` (`%CSP.REST` subclass), with 40 registered routes:

### Authentication

| Method | Path | Access | Handler | Description |
|--------|------|--------|---------|-------------|
| `POST` | `/api/auth/login` | Public | `Login` | Authenticate and return signed JWT |
| `POST` | `/api/auth/introspect` | Public | `Introspect` | SMART on FHIR token validation (RFC 7662) |
| `POST` | `/api/auth/debug` | Public | `AuthDebug` | Auth troubleshooting endpoint |

### Statistics & Metrics

| Method | Path | Access | Handler | Description |
|--------|------|--------|---------|-------------|
| `GET` | `/api/stats` | Protected | `GetStats` | System metrics (held count, approved today, risk distribution, model status) |
| `GET` | `/api/stats/trends` | Protected | `GetTrends` | 7-day weekly trend data |
| `GET` | `/api/stats/model-performance` | Protected | `GetModelPerformance` | Model precision metrics |
| `GET` | `/api/metrics` | Protected | `GetMetrics` | Prometheus-style operational metrics |
| `GET` | `/api/fhir/metadata` | Protected | `GetCapabilityStatement` | FHIR CapabilityStatement |

### Claims

| Method | Path | Access | Handler | Description |
|--------|------|--------|---------|-------------|
| `GET` | `/api/claims/held` | Protected | `GetHeldClaims` | Array of held (queued) ClaimResponses |
| `GET` | `/api/claims/export` | Protected | `ExportClaims` | CSV export of held claims |
| `GET` | `/api/claims/:id` | Protected | `GetClaimDetail` | Full claim detail with disposition and tier results |
| `POST` | `/api/claims/:id/approve` | Director+ | `ApproveClaim` | Approve (disburse) a held claim |
| `POST` | `/api/claims/:id/escalate` | Auditor+ | `EscalateClaim` | Escalate to director review (priority=stat) |
| `POST` | `/api/claims/:id/reject` | Director+ | `RejectClaim` | Reject a claim (outcome=error) |
| `POST` | `/api/claims/:id/reaudit` | Auditor+ | `ReauditClaim` | Re-run AI audit on a held claim |
| `POST` | `/api/claims/:id/generate-report` | Protected | `GenerateDetailedReport` | Generate detailed audit report |
| `POST` | `/api/claims/summarize-rationale` | Protected | `SummarizeRationale` | AI-summarize user rationale text |

### Chat & Assistant

| Method | Path | Access | Handler | Description |
|--------|------|--------|---------|-------------|
| `POST` | `/api/chat` | Protected | `Chat` | Non-streaming AI audit assistant chat |
| `POST` | `/api/chat/stream` | Protected | `ChatStream` | SSE streaming AI audit assistant chat |
| `GET` | `/api/chat/history/:id` | Protected | `GetChatHistory` | Load chat history for a claim |
| `POST` | `/api/chat/history/:id` | Protected | `SaveChatMessage` | Save a chat message for a claim |

### Ledger & Graph

| Method | Path | Access | Handler | Description |
|--------|------|--------|---------|-------------|
| `GET` | `/api/ledger` | Protected | `GetLedger` | Audit ledger of approved/escalated/rejected claims |
| `GET` | `/api/graph` | Protected | `GetCollusionGraph` | Collusion network graph data |

### LLM Settings

| Method | Path | Access | Handler | Description |
|--------|------|--------|---------|-------------|
| `GET` | `/api/settings/llm` | Admin | `GetLLMSettings` | Current LLM provider config |
| `POST` | `/api/settings/llm` | Admin | `UpdateLLMSettings` | Update LLM provider config |
| `GET` | `/api/settings/llm/ollama/models` | Admin | `GetOllamaModels` | List available Ollama models |

### System & Admin

| Method | Path | Access | Handler | Description |
|--------|------|--------|---------|-------------|
| `POST` | `/api/samples/load` | Admin | `LoadSampleData` | Seed sample FHIR data |
| `GET` | `/api/system/status` | Admin | `GetDataStatus` | Repository resource counts |
| `POST` | `/api/system/clear` | Admin | `ClearAllData` | Clear all test data |
| `POST` | `/api/system/upload` | Admin | `UploadClaimData` | Upload FHIR Claim or Bundle |
| `GET` | `/api/system/health` | Admin | `GetSystemHealth` | 6-component health check |
| `POST` | `/api/system/retrain-model` | Admin | `RetrainModel` | Retrain autoencoder |
| `GET` | `/api/system/admin-log` | Admin | `GetAdminLog` | Admin audit trail |
| `GET` | `/api/system/users` | Admin | `ListUsers` | List all users |
| `POST` | `/api/system/users` | Admin | `CreateUser` | Create new user |
| `PUT` | `/api/system/users/:username` | Admin | `UpdateUser` | Update user |
| `DELETE` | `/api/system/users/:username` | Admin | `DeleteUser` | Delete user |
| `GET` | `/api/system/backup` | Admin | `BackupRepository` | Download FHIR backup bundle |
| `POST` | `/api/system/backfill-tier-results` | Admin | `BackfillTierResults` | Backfill missing tier-result extensions |

> **Note:** Admin/data endpoints use the `/system/` prefix. The `/admin/` path prefix is blocked by IRIS CSP security and returns 401.

## Verification

```bash
# Check if FHIR server exists
docker exec claimaudit-iris iris session IRIS -U INTEROP <<< 'set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS cnt FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=? AND TABLE_NAME=?","HSFHIR_X0001_S","ClaimResponse") do rs.%Next() w rs.%Get("cnt")'

# Test FHIR endpoint
curl -s http://localhost:52773/fhir/r4/ClaimResponse

# Test API endpoint
curl -s http://localhost:52773/api/stats
```

## See Also
[[Initialization Script]] · [[ObjectScript SQL Single-Quote Consumption]] · [[Seed Data Disposition Validation]]
