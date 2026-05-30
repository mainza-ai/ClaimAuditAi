# API Endpoints

> The REST API is served at `/api/*` via `ClaimAudit.REST.Router` (%CSP.REST). All endpoints return JSON and use Basic Authentication (`_SYSTEM:SYS`).

## Endpoint Table

| Method | Path | Description | Response |
|--------|------|-------------|----------|
| `GET` | `/api/stats` | System metrics | `{"held": N, "approvedToday": N, "interceptedTotal": N, "modelStatus": "healthy", "leakageRate": N}` |
| `GET` | `/api/stats/trends` | 7-day trend data | `[{"day": "Mon", "processed": N, "held": N, "approved": N, "leakagePrevented": N}, ...]` |
| `GET` | `/api/claims/held` | Held (queued) claims | `[{"id": "...", "patientId": "...", "cptCode": "...", "riskScore": N, ...}]` |
| `GET` | `/api/claims/:id` | Claim detail | Full claim with parsed disposition and tier results |
| `POST` | `/api/claims/:id/approve` | Approve a held claim | `{"status": "success"}` |
| `POST` | `/api/claims/:id/escalate` | Escalate to director | `{"status": "success"}` |
| `GET` | `/api/ledger` | Audit ledger (approved/escalated) | `[{"id": "...", "claimId": "...", "action": "approved|escalated", ...}]` |
| `POST` | `/api/chat` | AI audit assistant | `{"response": "..."}` |
| `POST` | `/api/samples/load` | Seed FHIR sample data | `{"status": "success", "message": "..."}` |

## Rate Limiting & Polling

The UI polls the API every 15 seconds (`refetchInterval: 15000` in React Query). There is no WebSocket push mechanism.

## Error Format

All errors follow this JSON structure:

```json
{"error": "<error message>"}
```

When the error originates from IRIS, it may include additional `errors` array and `summary` fields.

## See Also
[[Blank UI Due to API Error Responses]] · [[ObjectScript SQL Single-Quote Consumption]]
