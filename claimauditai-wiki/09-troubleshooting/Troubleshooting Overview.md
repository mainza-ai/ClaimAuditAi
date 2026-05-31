# Troubleshooting Overview

> The troubleshooting section provides diagnostic guides to resolve common errors involving database compilation, Python libraries, API keys, FHIR validation, and ObjectScript pitfalls.

If your installation encounters errors, locate the symptom in the table below to find the relevant resolution guide:

| Troubleshooting Symptom | Likely Root Cause | Diagnostic Wiki Reference |
| :--- | :--- | :--- |
| Container fails to start or compile | Insufficient VM memory or file permission locks | [[Container Startup Failures]] |
| GET requests return 404 Not Found | Missing namespace or strategy endpoint mapping | [[FHIR Server 404]] |
| Claims are not intercepted (save normally) | Strategy classes not compiled or loaded | [[InteractionsStrategy Not Firing]] |
| Anomaly scores are too low (no holds) | Autoencoder bottleneck saturation or poor learning rates | [[Autoencoder Not Detecting Anomalies]] |
| Vector search returns empty sets | Malformed TO_VECTOR casting or missing HNSW index | [[Vector Search Returns No Results]] |
| AI Agent or MCP tools fail | Incorrect API keys, firewall limits, or port conflicts | [[AI Hub Tool Invocation Failures]] |
| **UI shows blank page / crashes on load** | API returns HTML/error instead of JSON; `.filter()` called on non-array | [[Blank UI Due to API Error Responses]] |
| **API returns `<METHOD DOES NOT EXIST> %Get,%SQL.StatementResult`** | ObjectScript consumes single quotes inside SQL strings | [[ObjectScript SQL Single-Quote Consumption]] |
| **Seed Sample Data button does nothing** | Emoji/CRLF chars in disposition violate FHIR string regex; empty claim reference | [[Seed Data Disposition Validation]] |
| **iris.script commands not executing** | Indented lines treated as continuations, never run as commands | [[iris.script Indentation Pitfalls]] |
| **Claim amounts always $0 in UI** | Claim resources not persisted by FHIR interceptor; total not stored in ClaimResponse | [[Claim Amounts Always $0]] |
| **LLM adjudication fails / Python exception** | NVIDIA_API_KEY invisible to Embedded Python; missing .llm_settings.json | [[LLM Provider Connection Failures]] |
| **Seed Sample Data times out after 60s** | Interceptor loads NLP model per-claim; total ~8 min for 8 claims | [[Seed Data Loading Timeout]] |
| **ClaimResponse FHIR validation errors** | `total` field must be an array of BackboneElement, not a Money object | [[ClaimResponse FHIR Validation]] |

## Key Details
- **Primary Diagnostic Command**: `docker logs --tail 100 claimaudit-iris`
- **Global Error Trap**: Query `^ClaimAuditError` or `^ClaimAuditStatusLog` in the `INTEROP` namespace to inspect runtime exceptions.
- **CSP Cache Flush**: Force cache flushes by running `kill ^%cspSession` in `%SYS`.

## See Also
[[Container Startup Failures]] · [[FHIR Server 404]] · [[InteractionsStrategy Not Firing]] · [[Blank UI Due to API Error Responses]] · [[ObjectScript SQL Single-Quote Consumption]]
