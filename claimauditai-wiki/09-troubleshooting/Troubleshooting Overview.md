# Troubleshooting Overview

> The troubleshooting section provides diagnostic guides to resolve common errors involving database compilation, Python libraries, API keys, and FHIR validation.

If your installation encounters errors, locate the symptom in the table below to find the relevant resolution guide:

| Troubleshooting Symptom | Likely Root Cause | Diagnostic Wiki Reference |
| :--- | :--- | :--- |
| Container fails to start or compile | Insufficient VM memory or file permission locks | [[Container Startup Failures]] |
| GET requests return 404 Not Found | Missing namespace or strategy endpoint mapping | [[FHIR Server 404]] |
| Claims are not intercepted (save normally) | Strategy strategy classes not compiled or loaded | [[InteractionsStrategy Not Firing]] |
| Anomaly scores are too low (no holds) | Autoencoder bottleneck saturation or poor learning rates | [[Autoencoder Not Detecting Anomalies]] |
| Vector search returns empty sets | Malformed TO_VECTOR casting or missing HNSW index | [[Vector Search Returns No Results]] |
| AI Agent or MCP tools fail | Incorrect API keys, firewall limits, or port conflicts | [[AI Hub Tool Invocation Failures]] |

## Key Details
- **Primary Diagnostic Command**: `docker logs --tail 100 claimaudit-iris`
- **Global Error Trap**: Query `^ClaimAuditError` in the `INTEROP` namespace to inspect runtime exceptions.
- **CSP Workaround**: Force cache flushes by running `do KillAllCSPJobs^%SYS.cspServer2()` in `%SYS`.

## See Also
[[Container Startup Failures]] · [[FHIR Server 404]] · [[InteractionsStrategy Not Firing]]