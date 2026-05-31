# API Endpoints

> The REST API is served at `/api/*` via `ClaimAudit.REST.Router` (%CSP.REST). All endpoints return JSON and use Basic Authentication (`_SYSTEM:SYS`).

## Endpoint Table

| Method | Path | Description | Response |
|--------|------|-------------|----------|
| `GET` | `/api/stats` | System metrics | `{"held": N, "approvedToday": N, "interceptedTotal": N, "totalValueHeld": N, "modelStatus": "...", "leakageRate": N, "riskDistribution": [...], "dailyInterceptedCounts": [...]}` |
| `GET` | `/api/stats/trends` | 7-day trend data | `[{"day": "Mon", "processed": N, "held": N, "approved": N, "leakagePrevented": N}, ...]` |
| `GET` | `/api/claims/held` | Held (queued) claims | `[{"id": "...", "patientId": "...", "patientName": "...", "cptCode": "...", "icdCode": "...", "totalAmount": N, "riskScore": N, "riskLevel": "critical|high|medium", "escalated": 0|1}, ...]` |
| `GET` | `/api/claims/:id` | Claim detail | Full claim with `disposition`, `tierResults`, `taskId`, `communicationRequestId`, `linkedClinicalNotes` |
| `POST` | `/api/claims/:id/approve` | Approve a held claim | Accepts `{"authorizedBy": "...", "rationaleRaw": "...", "rationaleSummary": "..."}` in body |
| `POST` | `/api/claims/:id/escalate` | Escalate to director | Accepts `{"authorizedBy": "...", "rationaleRaw": "...", "rationaleSummary": "..."}` in body |
| `POST` | `/api/claims/:id/reject` | Reject a claim | Accepts `{"authorizedBy": "...", "rationaleRaw": "...", "rationaleSummary": "..."}` in body |
| `GET` | `/api/ledger` | Audit ledger (approved/escalated) | `[{"id": "...", "claimId": "...", "action": "approved|escalated", "authorizedBy": "...", "timestamp": "...", "reason": "...", "amount": N}]` |
| `POST` | `/api/chat` | AI audit assistant | `{"response": "..."}` |
| `POST` | `/api/samples/load` | Seed FHIR sample data | `{"status": "success", "message": "..."}` |
| `GET` | `/api/graph` | Collusion network graph | `{"nodes": [...], "edges": [...], "insights": [...], "nodeCount": N, "edgeCount": N, "insightCount": N}` |
| `GET` | `/api/settings/llm` | Current LLM provider config | `{"provider": "nvidia|ollama|openai", "nvidiaModel": "...", "nvidiaKeySet": 0|1, ...}` |
| `POST` | `/api/settings/llm` | Update LLM provider config | Writes to `.llm_settings.json`, immediately active |
| `GET` | `/api/settings/llm/ollama/models` | List Ollama models | `["model1", "model2", ...]` |
| `POST` | `/api/claims/summarize-rationale` | AI-summarize audit rationale | Accepts `{"action": "approve|escalate|reject", "userText": "..."}`, returns `{"summary": "..."}` |

## Rate Limiting & Polling

The UI polls the API every 15 seconds (`refetchInterval: 15000` in React Query). There is no WebSocket push mechanism.

## Enriched Stats Response

The `GET /api/stats` endpoint now returns additional fields beyond the basic counts:

```json
{
  "held": 8,
  "approvedToday": 1,
  "interceptedTotal": 9,
  "totalValueHeld": 9895.00,
  "modelStatus": "healthy",
  "leakageRate": 0.89,
  "riskDistribution": [
    {"level": "critical", "count": 2},
    {"level": "high", "count": 4},
    {"level": "medium", "count": 2}
  ],
  "dailyInterceptedCounts": [
    {"date": "2026-05-24", "count": 0},
    {"date": "2026-05-25", "count": 0},
    {"date": "2026-05-30", "count": 8}
  ]
}
```

## Error Format

All errors follow this JSON structure:

```json
{"error": "<error message>"}
```

When the error originates from IRIS, it may include additional `errors` array and `summary` fields.

## See Also
[[Blank UI Due to API Error Responses]] · [[ObjectScript SQL Single-Quote Consumption]] · [[Claim Amounts Always $0]] · [[LLM Provider Connection Failures]]
