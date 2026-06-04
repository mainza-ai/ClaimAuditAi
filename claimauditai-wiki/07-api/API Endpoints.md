# API Endpoints

> The REST API is served at `/api/*` via `ClaimAudit.REST.Router` (%CSP.REST). Protected endpoints return JSON and require SMART on FHIR token authentication (`Authorization: Bearer <token>`).

## Authentication & Token Flow

To authenticate and obtain a JWT token, use the `/api/auth/login` public endpoint with valid credentials:
- **Admin:** `admin` / `ClaimAuditAdmin2026!` (full system access, seed/clear data)
- **Auditor:** `auditor` / `AuditReview2026!` (review holds, escalate to director)
- **Specialist:** `specialist` / `ReviewSpec2026!` (review escalated claims, escalate further)
- **Director:** `director` / `DirectorAudit2026!` (resolve escalated holds — approve/reject)
- **Viewer:** `viewer` / `ViewDash2026!` (read-only dashboard access)

Credentials are stored as HMAC-SHA256 hashes in INTEROP namespace globals (`^ClaimAuditAI("Users",...)`) — no namespace switching or `%SYS` access required. See [[Security Users Validate Crash]] for the authentication architecture.

Standard SMART on FHIR token validation also supports federated OpenID Connect (OIDC) identities via Keycloak (RS256 JWKS signatures).

### Login Request Body
```json
{
  "grant_type": "password",
  "username": "auditor",
  "password": "AuditReview2026!",
  "client_id": "claimaudit-ui"
}
```

### Login Success Response
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 86400,
  "scope": "launch patient/Patient.read user/Claim.read user/Claim.write user/ClaimResponse.read user/Task.read user/Task.write fhirUser online_access"
}
```

## Endpoint Table

| Method | Path | Access | Description | Response |
|--------|------|--------|-------------|----------|
| `POST` | `/api/auth/login` | Public | Authenticates credentials and returns a signed JWT | Standard OAuth2/SMART token object |
| `POST` | `/api/auth/introspect` | Public | SMART on FHIR token validation (RFC 7662) | `{"active": true, "sub": "...", "roles": [...], ...}` |
| `GET` | `/api/stats` | Protected | System metrics | `{"held": N, "approvedToday": N, "interceptedTotal": N, "totalValueHeld": N, "modelStatus": "...", "leakageRate": N, "riskDistribution": [...], "dailyInterceptedCounts": [...]}` |
| `GET` | `/api/stats/trends` | Protected | 7-day trend data | `[{"day": "Mon", "processed": N, "held": N, "approved": N, "leakagePrevented": N}, ...]` |
| `GET` | `/api/claims/held` | Protected | Held (queued) claims | `[{"id": "...", "patientId": "...", "patientName": "...", "providerId": "...", "cptCode": "...", "icdCode": "...", "totalAmount": N, "riskScore": N, "riskLevel": "critical|high|medium", "escalated": 0|1, "outcome": "queued|complete|error"}, ...]` |
| `GET` | `/api/claims/:id` | Protected | Claim detail | Full claim with `disposition`, `tierResults`, `taskId`, `taskStatus`, `taskPriority`, `communicationRequestId`, `escalated`, `outcome`, `actionHistory`, `linkedClinicalNotes`, `providerId` (from Claim) |
| `POST` | `/api/claims/:id/approve` | Director+ | Approve a held claim (writes to ledger, completes task) | Accepts `{"authorizedBy": "...", "rationaleSummary": "..."}` |
| `POST` | `/api/claims/:id/escalate` | Auditor+ | Escalate to director (sets task priority=stat in single step) | Accepts `{"authorizedBy": "...", "rationaleSummary": "..."}` |
| `POST` | `/api/claims/:id/reject` | Director+ | Reject a claim (outcome=error, cancels task) | Accepts `{"authorizedBy": "...", "rationaleSummary": "..."}` |
| `GET` | `/api/ledger` | Protected | Override audit ledger log (includes escalated tasks) | `[{"id": "...", "claimId": "...", "action": "approved|escalated|rejected", "authorizedBy": "...", "timestamp": "...", "reason": "...", "amount": N, "providerId": "..."}]` |
| `POST` | `/api/chat` | Protected | AI audit assistant chat | `{"response": "..."}` |
| `POST` | `/api/samples/load` | Admin | Seed FHIR sample data | `{"status": "success", "message": "..."}` |
| `GET` | `/api/graph` | Protected | Collusion network graph | `{"nodes": [...], "edges": [...], "insights": [...], "nodeCount": N, "edgeCount": N, "insightCount": N}` |
| `GET` | `/api/settings/llm` | Admin | Current LLM provider config | `{"provider": "nvidia|ollama|openai", "nvidiaModel": "...", "nvidiaBaseUrl": "...", ...}` |
| `POST` | `/api/settings/llm` | Admin | Update LLM provider config | Merges with existing `.llm_settings.json` (API keys survive updates) |
| `GET` | `/api/settings/llm/ollama/models` | Admin | List Ollama models | `["model1", "model2", ...]` |
| `POST` | `/api/claims/summarize-rationale` | Protected | AI-summarize audit rationale | Accepts `{"action": "approve|escalate|reject", "userText": "..."}`, returns `{"summary": "..."}` |
| `GET` | `/api/stats/model-performance` | Protected | Model precision metrics | `{"precision": N, "recall": "N/A", "f1": "N/A", "truePositives": N, "falsePositives": N, "note": "..."}` |
| `POST` | `/api/system/clear` | Admin | Clear all FHIR test data (also clears graph globals) | `{"success": true, "message": "..."}` |
| `GET` | `/api/system/status` | Admin | Repository resource counts (10 tables) | `{"claimResponses": N, "tasks": N, "patients": N, ..., "lastSeededAt": "..."}` |
| `POST` | `/api/system/upload` | Admin | Upload external FHIR data (Claim or Bundle) | Accepts JSON body; auto-creates ClaimProjections |
| `GET` | `/api/system/health` | Admin | 6-component system health check | `{"status": "healthy|degraded", "components": {"fhirEndpoint": {...}, "pythonBridge": {...}, "autoencoder": {...}, "graphEngine": {...}, "llm": {...}, "database": {...}}}` |
| `POST` | `/api/system/retrain-model` | Admin | Retrain autoencoder on current data (>5 claims) | `{"success": true|false, "message": "..."}` |
| `GET` | `/api/system/admin-log` | Admin | Admin audit trail | `{"data": [{"date", "timestamp", "action", "detail", "user"}, ...], "total": N}` |
| `GET` | `/api/system/users` | Admin | List all users with roles | `{"data": [{"username", "fullName", "roles": [...]}, ...], "total": N}` |
| `POST` | `/api/system/users` | Admin | Create user with HMAC-SHA256 hash | Accepts `{"username", "password", "fullName", "roles": [...]}` |
| `PUT` | `/api/system/users/:username` | Admin | Update user roles/password/name | Accepts `{"password", "fullName", "roles": [...]}` (password optional) |
| `DELETE` | `/api/system/users/:username` | Admin | Delete user (prevents last admin deletion) | Returns 400 if would remove only admin |
| `GET` | `/api/system/backup` | Admin | Download FHIR repository as transaction Bundle | `Content-Type: application/fhir+json` with attachment disposition |

> **Note:** Admin/data endpoints use the `/system/` prefix (not `/admin/`). The `/admin/` path prefix is blocked by IRIS CSP security settings and returns 401.

## Rate Limiting & Polling

The UI polls the API every 15 seconds (`refetchInterval: 15000` in React Query). There is no WebSocket push mechanism.

## Enriched Stats Response

The `GET /api/stats` endpoint returns:

```json
{
  "held": 8,
  "approvedToday": 1,
  "interceptedTotal": 9,
  "totalValueHeld": 9895.00,
  "modelStatus": "healthy",
  "leakageRate": 0.89,
  "riskDistribution": [
    {"level": "critical", "count": 1},
    {"level": "high", "count": 5},
    {"level": "medium", "count": 2}
  ],
  "dailyInterceptedCounts": [
    {"date": "2026-05-30", "count": 0},
    {"date": "2026-05-31", "count": 8}
  ]
}
```

- `approvedToday` is scoped to the current date via `SUBSTRING(_lastUpdated,1,10) = today` (dates derived from `$ZTIMESTAMP` UTC for accuracy across timezones).
- `riskDistribution` is derived from the `risk-score` ClaimResponse extension value (not disposition text). Thresholds: critical≥0.86 (all 3 AI tiers flagging), high≥0.50 (2 tiers), else medium (default). All three endpoints (GetHeldClaims, GetStats, GetClaimDetail) use the same classification logic.
- `dailyInterceptedCounts` covers the trailing 7 days (dates derived from `$ZTIMESTAMP` UTC).

## Timestamps & Timezones

All timestamps returned by the API use UTC (`$ZTIMESTAMP`) with ISO 8601 `Z` suffix (e.g., `"2026-06-04T16:00:00Z"`). The UI formats these in the browser's local timezone via `date-fns` and `toLocaleString()`. Date-range SQL comparisons (`SUBSTRING(_lastUpdated,1,10) = date`) also derive the comparison date from `$ZTIMESTAMP` to prevent off-by-one-day errors at timezone boundaries.

## Model Performance

`GET /api/stats/model-performance` returns precision derived from adjudication outcomes. Recall and F1 return `"N/A"` when no labeled ground truth exists — claims that pass without AI review cannot be classified as true/false negatives without external audit data:

```json
{
  "precision": 0.75, "recall": "N/A", "f1": "N/A",
  "truePositives": 3, "falsePositives": 1,
  "note": "Recall and F1 unavailable: requires labeled ground truth data for false negatives."
}
```

## System Health

`GET /api/system/health` checks 6 components: FHIR endpoint, Python bridge, autoencoder model, graph engine, LLM provider, and database counts. Returns `"healthy"` when all pass, `"degraded"` if any fail. Logged in the Data Management page.

## Error Format

All errors follow this JSON structure:

```json
{"error": "<error message>"}
```

When the error originates from IRIS, it may include additional `errors` array and `summary` fields.

## See Also
[[Blank UI Due to API Error Responses]] · [[ObjectScript SQL Single-Quote Consumption]] · [[Claim Amounts Always $0]] · [[LLM Provider Connection Failures]] · [[LLM API Key Lost on Save]]
