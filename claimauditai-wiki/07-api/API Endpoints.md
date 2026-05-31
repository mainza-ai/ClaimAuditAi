# API Endpoints

> The REST API is served at `/api/*` via `ClaimAudit.REST.Router` (%CSP.REST). All endpoints return JSON and use Basic Authentication (`_SYSTEM:SYS`).

## Endpoint Table

| Method | Path | Description | Response |
|--------|------|-------------|----------|
| `GET` | `/api/stats` | System metrics | `{"held": N, "approvedToday": N, "interceptedTotal": N, "totalValueHeld": N, "modelStatus": "...", "leakageRate": N, "riskDistribution": [...], "dailyInterceptedCounts": [...]}` |
| `GET` | `/api/stats/trends` | 7-day trend data | `[{"day": "Mon", "processed": N, "held": N, "approved": N, "leakagePrevented": N}, ...]` |
| `GET` | `/api/claims/held` | Held (queued) claims | `[{"id": "...", "patientId": "...", "patientName": "...", "cptCode": "...", "icdCode": "...", "totalAmount": N, "riskScore": N, "riskLevel": "critical|high|medium", "escalated": 0|1}, ...]` |
| `GET` | `/api/claims/:id` | Claim detail | Full claim with `disposition`, `tierResults`, `taskId`, `communicationRequestId`, `escalated`, `linkedClinicalNotes` |
| `POST` | `/api/claims/:id/approve` | Approve a held claim | Accepts `{"authorizedBy": "...", "rationaleSummary": "..."}`. Sets ClaimResponse outcome=complete, Task status=completed. |
| `POST` | `/api/claims/:id/escalate` | Escalate to director | Accepts `{"authorizedBy": "...", "rationaleSummary": "..."}`. Sets Task priority=stat. Claim stays queued but shows escalated badge. |
| `POST` | `/api/claims/:id/reject` | Reject a claim | Accepts `{"authorizedBy": "...", "rationaleSummary": "..."}`. Sets ClaimResponse outcome=error, Task status=cancelled. |
| `GET` | `/api/ledger` | Audit ledger (approved/rejected/escalated) | `[{"id": "...", "claimId": "...", "action": "approved|escalated|rejected", "authorizedBy": "...", "timestamp": "...", "reason": "...", "amount": N}]` |
| `POST` | `/api/chat` | AI audit assistant | `{"response": "..."}` |
| `POST` | `/api/samples/load` | Seed FHIR sample data | `{"status": "success", "message": "..."}` |
| `GET` | `/api/graph` | Collusion network graph | `{"nodes": [...], "edges": [...], "insights": [...], "nodeCount": N, "edgeCount": N, "insightCount": N}` |
| `GET` | `/api/settings/llm` | Current LLM provider config | `{"provider": "nvidia|ollama|openai", "nvidiaModel": "...", "nvidiaBaseUrl": "...", ...}` |
| `POST` | `/api/settings/llm` | Update LLM provider config | Merges with existing `.llm_settings.json` (API keys survive partial updates). Immediately active. |
| `GET` | `/api/settings/llm/ollama/models` | List Ollama models | `["model1", "model2", ...]` |
| `POST` | `/api/claims/summarize-rationale` | AI-summarize audit rationale | Accepts `{"action": "approve|escalate|reject", "userText": "..."}`, returns `{"summary": "..."}` |
| `POST` | `/api/system/clear` | Clear all FHIR test data | `{"success": true, "message": "..."}` |
| `GET` | `/api/system/status` | Repository resource counts | `{"claimResponses": N, "tasks": N, "patients": N}` |
| `POST` | `/api/system/upload` | Upload external FHIR data | Accepts Claim or Bundle JSON body. Returns `{"success": true, "fhirStatus": N, "resourceType": "..."}` |

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
- `riskDistribution` is derived from disposition text keyword matching
- `dailyInterceptedCounts` covers the trailing 7 days

## Error Format

All errors follow this JSON structure:

```json
{"error": "<error message>"}
```

When the error originates from IRIS, it may include additional `errors` array and `summary` fields.

## See Also
[[Blank UI Due to API Error Responses]] · [[ObjectScript SQL Single-Quote Consumption]] · [[Claim Amounts Always $0]] · [[LLM Provider Connection Failures]] · [[LLM API Key Lost on Save]]
