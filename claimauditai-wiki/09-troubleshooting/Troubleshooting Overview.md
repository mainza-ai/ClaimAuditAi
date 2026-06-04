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
| **Login returns "Invalid credentials" for valid users** | `%SYSTEM.Security.Login()` incompatible with REST context; CSP UnknownUser lacks `%SYS` access | [[Security Users Validate Crash]] |
| **UI shows blank page / crashes on load** | API returns HTML/error instead of JSON; `.filter()` called on non-array | [[Blank UI Due to API Error Responses]] |
| **API returns `<METHOD DOES NOT EXIST> %Get,%SQL.StatementResult`** | ObjectScript consumes single quotes inside SQL strings | [[ObjectScript SQL Single-Quote Consumption]] |
| **Seed Sample Data button does nothing** | Emoji/CRLF chars in disposition violate FHIR string regex; empty claim reference | [[Seed Data Disposition Validation]] |
| **iris.script commands not executing** | Indented lines treated as continuations, never run as commands | [[iris.script Indentation Pitfalls]] |
| **Claim amounts always $0 in UI** | Claim resources not persisted by FHIR interceptor; total not stored in ClaimResponse | [[Claim Amounts Always $0]] |
| **LLM adjudication fails / Python exception** | NVIDIA_API_KEY invisible to Embedded Python; missing .llm_settings.json; httpx/openai version conflict | [[LLM Provider Connection Failures]] |
| **Claim actions return 404 or silently fail** | Missing UrlMap routes, PUT response not validated, FHIR datetime format rejected, `$Get()` on dynamic object, escalation `Quit` inside `While` without flag variable | [[Claim Actions Silently Fail]] |
| **Rejected claims do not appear in the audit ledger** | GetLedger SQL excluded `status='cancelled'` tasks | [[Rejected Claims Missing From Ledger]] |
| **Escalated claims do not appear in ledger or show escalation badge** | EscalateClaim only set `priority="stat"` on second escalation (ready→requested→received). First escalation kept `priority="urgent"` — invisible to both GetHeldClaims badge check and GetLedger query. Ledger query required `(status='ready' AND priority='stat')` which was impossible after escalation changed status to `requested`. | Fixed: all escalations now set `priority="stat"` immediately; GetLedger matches any task with `priority="stat"` |
| **Timestamp mismatch between Ledger and Data pages** | `$HOROLOG` (local time) used with `"Z"` UTC suffix — falsified UTC by server's UTC offset. `$ZTIMESTAMP` (true UTC) used without `"Z"` suffix — JavaScript parsed as local time. SQL date comparisons used `$HOROLOG` (local) against `_lastUpdated` (UTC) — off by 1 day at UTC midnight. | Fixed: all timestamps use `$ZTIMESTAMP+"Z"`; all SQL comparisons derive dates from `$ZTIMESTAMP` |
| **Role name not recognized / "Viewer" users show as "Auditor"** | `deriveActiveRole()` never returned level 1 (Viewer); `UserRole` union type excluded "Viewer". Backend stored "Admin" but frontend checked for "Tech Owner / Admin". | Fixed: Viewer added to type and derivation; naming normalized to "Admin" everywhere |
| **Dashboard metrics never update after claim actions** | Dashboard queries have no `refetchInterval`; HoldQueue refetches stale cache | [[Dashboard Metrics Stale After Actions]] |
| **Daily intercepted chart shows all zeros** | `CAST(_lastUpdated AS DATE)` returns horolog integer, not date string | [[Dashboard Daily Counts Always Zero]] |
| **Trend chart day names all show "Sun"** | $ZDATE format 11 returns weekday abbreviation string, not number; LISTGET index off-by-one | [[Dashboard Daily Counts Always Zero]] |
| **Dark mode does not persist on page refresh** | `applyTheme()` not called during Zustand store initialization | [[Theme Not Applied on Page Load]] |
| **Admin endpoints (/api/admin/*) return 401 Unauthorized** | IRIS CSP web application blocks the `/admin/` path prefix | [[Admin Routes Return 401]] |
| **LLM API key lost after saving settings** | UpdateLLMSettings overwrites file; key name mismatch between frontend and backend | [[LLM API Key Lost on Save]] |
| **Autoencoder flags claims randomly** | Model trained on 200 synthetic random noise claims when real data < 10 | [[Autoencoder Trains on Random Noise]] |
| **Claims in Bundles are not audited** | OnBeforeRequest only checks `Type="Claim"`, not `Type="Bundle"` | [[Bundle Claims Not Intercepted]] |
| **Collusion graph fails to detect new edges / flags silently suppressed** | Graph was cached with 30s TTL and not invalidated between claims; exceptions returned `flagged=False` masking infrastructure failures | [[Collusion Graph Performance Degradation]] |
| **Risk distribution shows all same level / mismatched between pages** | GetClaimDetail used LLM disposition text matching instead of risk-score extension with numeric thresholds (≥0.86→critical, ≥0.50→high, else→medium) | [[Seed Data Disposition Validation]] |
| **F1 score always shows "N/A" in model performance** | Recall and F1 require labeled ground truth (which claims were actually fraudulent). Without external labels, false negatives cannot be measured — "N/A" is the correct value | [[API Endpoints]] |
| **System health dashboard shows "degraded"** | One or more of 6 components (FHIR, Python, autoencoder, graph, LLM, database) failed validation | [[Container Startup Failures]] |
| **Admin audit log returns empty** | No admin actions logged yet, or `^ClaimAuditAdminLog` global was cleared | Seed/clear/upload/retrain data to generate audit entries |
| **User CRUD returns 409/400** | Duplicate username, missing fields, or attempted deletion of last remaining admin user | Check request payload; ensure at least one Admin role user exists |
| **Retrain model fails** | Fewer than 5 claim projections in database, or autoencoder Python module unavailable | Seed/upload at least 5 claims before retraining |

## Key Details
- **Primary Diagnostic Command**: `docker logs --tail 100 claimaudit-iris`
- **Global Error Trap**: Query `^ClaimAuditError` or `^ClaimAuditStatusLog` in the `INTEROP` namespace to inspect runtime exceptions.
- **CSP Cache Flush**: Force cache flushes by running `kill ^%cspSession` in `%SYS`.

## See Also
[[Container Startup Failures]] · [[FHIR Server 404]] · [[InteractionsStrategy Not Firing]] · [[Blank UI Due to API Error Responses]] · [[ObjectScript SQL Single-Quote Consumption]] · [[Claim Actions Silently Fail]] · [[Rejected Claims Missing From Ledger]] · [[Dashboard Metrics Stale After Actions]] · [[Dashboard Daily Counts Always Zero]] · [[Theme Not Applied on Page Load]] · [[Admin Routes Return 401]] · [[LLM API Key Lost on Save]] · [[Autoencoder Trains on Random Noise]] · [[Bundle Claims Not Intercepted]] · [[Collusion Graph Performance Degradation]]
