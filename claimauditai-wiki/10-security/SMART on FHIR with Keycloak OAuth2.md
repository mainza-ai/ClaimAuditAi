# SMART on FHIR with Keycloak OAuth2

> ClaimAuditAI implements standard SMART on FHIR authentication using federated OpenID Connect (OIDC) identity providers (like Keycloak) with fallback local developer flow.

The security implementation in `ClaimAudit.REST.Auth` supports two token signature verification methods:
1. **RS256 Signature Verification** (Production OIDC/Keycloak federated identities)
2. **HS256 Signature Verification** (Local developer identity flow)

---

## 1. Production OIDC / Keycloak Integration (RS256)

In a production environment, user authentication is delegated to Keycloak (or any standard OIDC identity provider). 

### JWKS Key Retrieval & Caching
To verify RS256 signatures, the backend dynamically fetches Keycloak's public keys from the JWKS (JSON Web Key Set) endpoint:
- **Environment Variable**: `JWKS_URI` (e.g., `http://keycloak:8080/realms/claimaudit/protocol/openid-connect/certs`)
- **Key Caching**: The public keys are cached in the local database global `^ClaimAuditJWKS` for **1 hour** (3600 seconds) to avoid performing network roundtrips on every API call.
- **Failover Resilience**: If the JWKS endpoint is temporarily unreachable, the validation engine falls back to the expired cached keys, preventing service disruption during temporary OIDC outages.

### Token Verification Flow
```
Client Request (Bearer JWT)
       │
       ▼
Extract Token Header ──> Read 'alg' (RS256) & 'kid' (Key ID)
       │
       ▼
Check Local Cache (^ClaimAuditJWKS)
       ├──> Found & Valid: Verify signature using cached certificate PEM
       └──> Expired/Not Found: Fetch fresh JWKS keys from JWKS_URI
```

---

## 2. Local Developer Token Flow (HS256)

For local development, testing, and automated seeding where Keycloak is not deployed, the backend implements a local token provider flow.

- **Endpoint**: `/api/auth/login`
- **Signing Algorithm**: HMAC-SHA256 (HS256)
- **Local Secret Management**:
  - Environment variable `JWT_SECRET` is checked first.
  - In development environments (`CLAIMAUDIT_ENV != "production"`), if `JWT_SECRET` is not set, a persistent random UUID is generated on startup and stored securely in the local namespace global `^ClaimAuditAI("Secret")`.
  - In production mode, a missing `JWT_SECRET` is treated as a critical security violation, logging a timestamped alert to `^ClaimAuditSecurityError` and throwing a hard error to prevent weak token signing.
- **User Validation**: Validates username and password against HMAC-SHA256 credential hashes stored in INTEROP namespace globals (`^ClaimAuditAI("Users",...)`). These hashes are populated at build time by `iris.script` and do not require `%SYS` namespace access or interactive context. See [[Security Users Validate Crash]] for the architecture rationale.

---

## 3. JWT Claims & SMART on FHIR Scopes

Regardless of the signature algorithm, tokens are expected to contain standard SMART on FHIR claims.

### Claims Mapping
- `sub`: The username/identity identifier.
- `iss`: The token issuer (configured via `JWKS_ISSUER` or defaulting to `https://claimauditai.com/fhir`).
- `aud`: Client application ID (e.g., `claimaudit-ui`).
- `name`: Human-readable full name of the user (extracted from Keycloak mapping or IRIS FullName).
- `fhirUser`: Resource path pointing to the practitioner profile (e.g., `Practitioner/auditor`).
- `roles`: Realm access roles (e.g., `["Viewer"]`, `["Auditor"]`, `["Admin"]`).
- `scope`: Standard SMART on FHIR scopes:
  `launch patient/Patient.read user/Claim.read user/Claim.write user/ClaimResponse.read user/Task.read user/Task.write fhirUser online_access`

---

## 4. API Authorization & Roles Hierarchy

Application-level endpoint security is enforced via a numerical role hierarchy in the middleware:

| Role Name | Numeric Level | Required Scope / Description |
| :--- | :--- | :--- |
| **Viewer** | 1 | View dashboard statistics (Read-only) |
| **Auditor** | 2 | Perform manual reviews (Approve, Escalated, Reject) |
| **Specialist** | 3 | View network collusion graphs, execute overrides |
| **Director** | 4 | Final approval/rejection overrides |
| **Admin** | 5 | Modify LLM settings, re-train models, reload data |

Roles are parsed from Keycloak's `realm_access.roles` claim or the token's top-level `roles` array. Higher roles inherit the capabilities of all lower roles.

---

## See Also
* [[IRIS Role-Based Access Control]]
* [[API Endpoints]]
* [[Security Overview]]
