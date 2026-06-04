# Login Returns "Invalid credentials" / Security.Users Validate Crash

> CSP Gateway web requests run as `UnknownUser` without `%SYS` database access. Attempting `zn "%SYS"` to call `Security.Users` APIs throws `<PROTECT>`, and `%SYSTEM.Security.Login()` is an interactive-only API that returns false in REST contexts — even with correct credentials.

### Symptom

1. **Login returns "Invalid credentials"** for known valid users (`admin` / `ClaimAuditAdmin2026!`, `auditor` / `AuditReview2026!`) even though credentials are correct:
   ```json
   {"error":"invalid_grant","error_description":"Invalid credentials"}
   ```

2. **Protect Errors:** Attempting to switch namespace to `%SYS` inside a CSP web request:
   ```objectscript
   zn "%SYS"
   ```
   results in:
   ```
   <PROTECT> *zn "%SYS"
   ```

3. **Method Does Not Exist:** Calling `##class(Security.Users).Validate()` — `Security.Users` has no `Validate` classmethod.

4. **`%SYSTEM.Security.Login()` returns false:** Even with correct credentials, `##class(%SYSTEM.Security).Login()` returns 0 in REST contexts because it requires an interactive terminal device (`$IO`), which the CSP response stream is not.

### Root Cause

The CSP Gateway dispatches REST requests as `UnknownUser` — an unauthenticated user without `%SYS` database access. Any attempt to:

- Switch to `%SYS` namespace (`zn "%SYS"`) → `<PROTECT>`
- Read `^SYS("Security",...)` globals → `<PROTECT>`
- Call `%SYSTEM.Security.Login()` → returns false (non-interactive context)
- Call `Security.Users.Validate()` → method doesn't exist

The core challenge is that token-based authentication (JWT) should NOT change the process identity. The JWT carries the user's identity and roles — the CSP process should remain `UnknownUser` and authorize via token claims, not by changing its IRIS process identity.

### Resolution: Local Credential Store in INTEROP Namespace

Store user credential hashes and roles in the INTEROP namespace during container startup, and validate against them without any namespace switching.

#### 1. Store Credential Hashes at Build Time (`iris.script`)

In `iris.script`, after creating users in `%SYS`, switch to `INTEROP` and store HMAC-SHA256 hashes:

```objectscript
zn "INTEROP"
Set tSalt = "ClaimAuditAI_Salt"
Set ^ClaimAuditAI("Users","admin","hash") = $SYSTEM.Encryption.HMACSHA(256, "ClaimAuditAdmin2026!", tSalt)
Set ^ClaimAuditAI("Users","admin","fullName") = "ClaimAuditAI Admin"
Set ^ClaimAuditAI("Users","admin","roles","Admin") = ""
Set ^ClaimAuditAI("Users","auditor","hash") = $SYSTEM.Encryption.HMACSHA(256, "AuditReview2026!", tSalt)
Set ^ClaimAuditAI("Users","auditor","fullName") = "ClaimAuditAI Auditor"
Set ^ClaimAuditAI("Users","auditor","roles","Auditor") = ""
Set ^ClaimAuditAI("Users","viewer","hash") = $SYSTEM.Encryption.HMACSHA(256, "ViewDash2026!", tSalt)
Set ^ClaimAuditAI("Users","viewer","fullName") = "ClaimAuditAI Viewer"
Set ^ClaimAuditAI("Users","viewer","roles","Viewer") = ""
```

These globals are in the INTEROP namespace — fully accessible to the CSP `UnknownUser` process.

> **Important:** After a Docker container restart or rebuild, these globals must be re-populated. Run `iris session IRIS -U INTEROP` and paste the commands above, or re-run the container's init scripts.

#### 2. Validate Credentials in `Login()` (`Router.cls`)

Replace `%SYSTEM.Security.Login()` with direct hash comparison:

```objectscript
// CORRECT: Validate against local credential store (INTEROP globals)
Set tHash = $SYSTEM.Encryption.HMACSHA(256, tPassword, "ClaimAuditAI_Salt")
Set tStoredHash = $Get(^ClaimAuditAI("Users", tUsername, "hash"))
If (tStoredHash = "") || (tHash '= tStoredHash) {
    Set %response.Status = 401
    Write {"error":"invalid_grant","error_description":"Invalid credentials"}.%ToJSON()
    Quit
}
```

No namespace switch needed. No `%SYS` access required. No interactive context dependency.

#### 3. Read Roles from Local Globals in `IssueSmartOnFHIRToken()` (`Auth.cls`)

Replace `$Roles` (which requires process identity change) with direct global reads:

```objectscript
// Read FullName from local credential store
Set tFullName = $Get(^ClaimAuditAI("Users", pUsername, "fullName"), pUsername)

// Read roles from local credential store (no namespace switch needed)
Set tRoles = []
Set tSub = ""
For {
    Set tSub = $Order(^ClaimAuditAI("Users", pUsername, "roles", tSub))
    If tSub = "" Quit
    Do tRoles.%Push(tSub)
}
```

This completely decouples JWT issuance from the IRIS process identity — the correct pattern for token-based authentication.

### Why This Approach is Correct for Production

| Approach | Works? | Issue |
|----------|--------|-------|
| `zn "%SYS"` + `Security.Users` | No | `<PROTECT>` — CSP UnknownUser has no `%SYS` access |
| `%SYSTEM.Security.Login()` | No | Interactive-only API returns false in REST contexts |
| `$Roles` for JWT roles | No | Chicken-and-egg: JWT can't be issued unless process identity was changed |
| **Local HMAC globals in INTEROP** | **Yes** | No namespace switching, no interactive dependency, CSP-native |

### Affected Files

- `iris.script` — credential hash storage (build time)
- `src/cls/ClaimAudit/REST/Router.cls` — `Login()` hash validation
- `src/cls/ClaimAudit/REST/Auth.cls` — `IssueSmartOnFHIRToken()` role/name retrieval

### Verification

```bash
# 1. Verify hashes exist
docker exec -it claimaudit-iris iris session IRIS -U INTEROP
> Write $Get(^ClaimAuditAI("Users","admin","hash"))
# Should output a non-empty hex hash

# 2. Test login
curl -s -X POST http://localhost:52773/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"grant_type":"password","username":"admin","password":"ClaimAuditAdmin2026!","client_id":"claimaudit-ui"}'
# Should return: {"access_token":"eyJ...","token_type":"bearer",...}

# 3. Verify JWT contains roles
# Paste the access_token into jwt.io or decode the payload — "roles" should be ["Admin"]
```

## See Also
[[IRIS Role-Based Access Control]] · [[SMART on FHIR with Keycloak OAuth2]] · [[Admin Routes Return 401]]
