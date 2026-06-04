# API Endpoints

> The REST API is served at `/api/*` via `ClaimAudit.REST.Router` (%CSP.REST). Protected endpoints return JSON and require SMART on FHIR token authentication (`Authorization: Bearer <token>`).

## Authentication & Token Flow

To authenticate and obtain a JWT token, use the `/api/auth/login` public endpoint with valid credentials:
- **Admin:** `admin` / `ClaimAuditAdmin2026!` (full system access, seed/clear data)
- **Auditor:** `auditor` / `AuditReview2026!` (review holds, approve/reject/escalate)
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
| `GET` | `/api/claims/held` | Protected | Held (queued) claims | `[{"id": "...", "patientId": "...", "patientName": "...", "cptCode": "...", "icdCode": "...", "totalAmount": N, "riskScore": N, "riskLevel": "critical|high|medium", "escalated": 0|1}, ...]` |
| `GET` | `/api/claims/:id` | Protected | Claim detail | Full claim with `disposition`, `tierResults`, `taskId`, `communicationRequestId`, `escalated`, `linkedClinicalNotes` |
| `POST` | `/api/claims/:id/approve` | Auditor+ | Approve a held claim (writes to ledger, completes task) | Accepts `{"authorizedBy": "...", "rationaleSummary": "..."}` |
| `POST` | `/api/claims/:id/escalate` | Auditor+ | Escalate to director (sets priority=stat) | Accepts `{"authorizedBy": "...", "rationaleSummary": "..."}` |
| `POST` | `/api/claims/:id/reject` | Auditor+ | Reject a claim (outcome=error, cancels task) | Accepts `{"authorizedBy": "...", "rationaleSummary": "..."}` |
| `GET` | `/api/ledger` | Protected | Override audit ledger log | `[{"id": "...", "claimId": "...", "action": "approved|escalated|rejected", "authorizedBy": "...", "timestamp": "...", "reason": "...", "amount": N}]` |
| `POST` | `/api/chat` | Protected | AI audit assistant chat | `{"response": "..."}` |
| `POST` | `/api/samples/load` | Admin | Seed FHIR sample data | `{"status": "success", "message": "..."}` |
| `GET` | `/api/graph` | Protected | Collusion network graph | `{"nodes": [...], "edges": [...], "insights": [...], "nodeCount": N, "edgeCount": N, "insightCount": N}` |
| `GET` | `/api/settings/llm` | Admin | Current LLM provider config | `{"provider": "nvidia|ollama|openai", "nvidiaModel": "...", "nvidiaBaseUrl": "...", ...}` |
| `POST` | `/api/settings/llm` | Admin | Update LLM provider config | Merges with existing `.llm_settings.json` (API keys survive updates) |
| `GET` | `/api/settings/llm/ollama/models` | Admin | List Ollama models | `["model1", "model2", ...]` |
| `POST` | `/api/claims/summarize-rationale` | Protected | AI-summarize audit rationale | Accepts `{"action": "approve|escalate|reject", "userText": "..."}`, returns `{"summary": "..."}` |
| `POST` | `/api/system/clear` | Admin | Clear all FHIR test data | `{"success": true, "message": "..."}` |
| `GET` | `/api/system/status` | Admin | Repository resource counts | `{"claimResponses": N, "tasks": N, "patients": N}` |
| `POST` | `/api/system/upload` | Admin | Upload external FHIR data | Accepts Claim or Bundle JSON body |

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

- `approvedToday` is scoped to the current date via `SUBSTRING(_lastUpdated,1,10) = today`
- `riskDistribution` is derived from the `risk-score` ClaimResponse extension value (not disposition text). Thresholds: critical≥0.86 (all 3 AI tiers), high≥0.50 (2 tiers), medium≥0.30 (1 tier).
- `dailyInterceptedCounts` covers the trailing 7 days

## Error Format

All errors follow this JSON structure:

```json
{"error": "<error message>"}
```

When the error originates from IRIS, it may include additional `errors` array and `summary` fields.

## See Also
[[Blank UI Due to API Error Responses]] · [[ObjectScript SQL Single-Quote Consumption]] · [[Claim Amounts Always $0]] · [[LLM Provider Connection Failures]] · [[LLM API Key Lost on Save]]
