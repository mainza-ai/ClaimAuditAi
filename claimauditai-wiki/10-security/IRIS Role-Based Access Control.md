# IRIS Role-Based Access Control

> Role-Based Access Control (RBAC) secures database access by restricting schema access and managing passwordless CallIn services.

To secure database access:
1. **Schema Access Limits**: Access to the projected SQL tables under the `ClaimAudit` schema is restricted to the `/interop/fhir/r4` service account.
2. **Passwordless CallIn Configuration**: Enabled using `merge.cpf` to allow passwordless connections for local Python processes, while maintaining strict password enforcement for external database clients.

```
External Client (REST) ──> Required Basic Authentication (_SYSTEM/SYS) ──> IRIS DB
Local Process (CallIn)  ──> Allowed Passwordless CallIn Connection       ──> IRIS DB
```

This multi-layered access architecture protects the database from unauthorized external access while maintaining fast, native local data access.

## Key Details
- **Operational Schema**: `ClaimAudit.*`
- **SuperServer Port**: 1972 (requires password authentication).
- **Local CallIn Service**: `%Service_CallIn` (configured via `merge.cpf`).
- **Gateway Accounts**: Restrict default credentials (`_SYSTEM` / `SYS`) before deploying to staging environments.

## See Also
[[Security Overview]] · [[FHIR Interception Strategy]] · [[Docker Configuration]]