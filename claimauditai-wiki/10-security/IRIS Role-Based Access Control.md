# IRIS Role-Based Access Control & API RBAC

> Role-Based Access Control (RBAC) secures database access by restricting schema access and managing passwordless CallIn services, while custom token-based claims enforce application-level privileges.

## Database Access Hardening

1. **Schema Access Limits**: Access to the projected SQL tables under the `ClaimAudit` schema is restricted to the `/fhir/r4` service account and authorized REST roles.
2. **Minimal Privilege Principle**: The unauthenticated `UnknownUser` system account is strictly hardened. The superuser role (`%All`) has been revoked. `UnknownUser` is instead granted minimal fine-grained roles (`%DB_INTEROP-CODE`, `%DB_INTEROP-DATA`, `%HS_DB_INTEROP`, `%DB_INTEROPX0001R`, `%DB_INTEROPX0001V`, `%HS_ServiceRole`, and `%HS_Administrator`) along with explicit schema-level SQL permissions (`SELECT, INSERT, UPDATE, DELETE`) on the `HSFHIR_X0001_S`, `HSFHIR_X0001_R`, `HSFHIR_X0001_V`, and `ClaimAudit` schemas.
3. **Passwordless CallIn Configuration**: Enabled using `merge.cpf` to allow passwordless connections for local Python processes, while maintaining strict password enforcement for external database clients.

```
External Client (REST) ──> Bearer JWT or Basic Credentials ──> IRIS DB
Local Process (CallIn)  ──> Allowed Passwordless CallIn      ──> IRIS DB
```

## API Role-Based Access Control (RBAC)

The `/api/*` endpoints validate token signatures (HS256 local, RS256 Keycloak) and check user scopes and role claims. A numeric role level hierarchy is enforced by `ClaimAudit.REST.Auth` class:

| Role Name | Numeric Level | Inherited Capabilities |
| :--- | :--- | :--- |
| **Viewer** | 1 | View claims dashboard and read-only statistics. Cannot perform any claim actions. |
| **Auditor** | 2 | View the active pended held claim queue, escalate anomalies to Director (single-step with `priority=stat`). Cannot approve or reject. |
| **Specialist** | 3 | View the collusion graph, receive escalated claims for deeper analysis, escalate further to Director. Can also escalate but cannot approve or reject. |
| **Director** | 4 | Resolve escalated pended holds — Approve claims (disburse) or Reject claims (deny and cancel). Author final ledger override summaries. |
| **Admin** | 5 | Manage users (CRUD with PBKDF2-SHA256 credential hashing), retrain autoencoder models, modify system-wide LLM settings, clear/seed test data, view system health dashboard, download FHIR repository backup, review admin audit log. |

Higher level roles automatically bypass restrictions for lower levels (e.g., a Director or Admin inherits Auditor and Specialist abilities).

## Key Details
- **Operational Schema**: `ClaimAudit.*`
- **SuperServer Port**: 1972 (requires password authentication).
- **Local CallIn Service**: `%Service_CallIn` (configured via `merge.cpf`).
- **Access Rule Policy**: Restricts database write permissions to the `/fhir/r4` service account.

## See Also
[[Security Overview]] · [[FHIR Interception Strategy]] · [[Docker Configuration]]