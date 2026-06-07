# FHIR Server Provisioning

> The FHIR server configuration provisions the `/fhir/r4` endpoint and registers the custom `ClaimAudit.FHIR.InteractionsStrategy`.

## Architecture

The FHIR server runs in the `INTEROP` namespace. It is created at **container runtime** by `init_iris.sh` (not during Docker build), because the FHIR framework classes (`HS.FHIRServer.Storage.Json.*`) are only available after the namespace is fully initialized:

```
Runtime Flow:
  init_iris.sh
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

The `/api` web application at `http://localhost:52773/api/*` is dispatched by `ClaimAudit.REST.Router` (`%CSP.REST` subclass):

| Endpoint | Method | Handler | Returns |
|----------|--------|---------|---------|
| `/api/stats` | GET | `GetStats` | System metrics (held count, approved today, model status) |
| `/api/stats/trends` | GET | `GetTrends` | 7-day weekly trend data |
| `/api/claims/held` | GET | `GetHeldClaims` | Array of held (queued) ClaimResponses |
| `/api/claims/:id` | GET | `GetClaimDetail` | Full claim detail with parsed disposition |
| `/api/claims/:id/approve` | POST | `ApproveClaim` | Approve (disburse) a held claim |
| `/api/claims/:id/escalate` | POST | `EscalateClaim` | Escalate to director review |
| `/api/ledger` | GET | `GetLedger` | Audit ledger of approved/escalated claims |
| `/api/chat` | POST | `Chat` | LLM-powered audit assistant |
| `/api/samples/load` | POST | `LoadSampleData` | Seed sample FHIR bundles for testing |

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
