# Security.Users.Validate Method Crash & <PROTECT> Errors

> When authenticating local users (e.g., in `/api/auth/login`), switching to the `%SYS` namespace to call `Security.Users` methods throws a `<PROTECT>` error under unprivileged web request contexts, and using the wrong validation APIs causes method-does-not-exist errors.

### Symptom

1. **Method Does Not Exist:** Calling `##class(Security.Users).Validate(tUsername, tPassword)` results in:
   ```
   <METHOD DOES NOT EXIST> *Validate^Security.Users
   ```

2. **Protect Errors:** Attempting to switch namespace to `%SYS` inside a CSP web request (running as the unauthenticated `UnknownUser` or a standard user role):
   ```objectscript
   zn "%SYS"
   ```
   results in a database security crash:
   ```
   <PROTECT> *zn "%SYS"
   ```

### Root Cause

- The class `Security.Users` does not contain a static classmethod called `Validate`.
- Standard web requests do not have permissions to access the system default databases (`IRISSYS`, `IRISsys`) or the `%SYS` namespace, so executing `zn "%SYS"` or reading/writing system globals like `^%SYS` throws a security `<PROTECT>` exception.

### Resolution

To authenticate a user securely and perform authorization without namespace switching:

1. **Use `%SYSTEM.Security.Login`:**
   Use the system-wide class method `##class(%SYSTEM.Security).Login(username, password)`. This method can be called from any namespace (including `INTEROP`) without switching namespace to `%SYS`, and it automatically changes the process identity to the authenticated user and populates their assigned roles in `$Roles`.

   ```objectscript
   // Correct Implementation:
   Set tIsValid = ##class(%SYSTEM.Security).Login(tUsername, tPassword)
   If 'tIsValid {
       Set %response.Status = 401
       Write {"error": "invalid_grant"}.%ToJSON()
       Quit
   }
   ```

2. **Retrieve Roles from `$Roles`:**
   Avoid looping over restricted system globals like `^SYS("Security", ...)`. Read roles from the local process variable `$Roles` after a successful login:

   ```objectscript
   Set tRolesStr = $Roles
   // Map ClaimAdmin, ClaimAuditor, ClaimViewer to simple roles
   ```

3. **Store JWT Secret Locally:**
   Store dev JWT keys in a local namespace global (e.g., `^ClaimAuditAI("Secret")`) instead of system globals (e.g., `^%SYS("ClaimAuditAI")`) to prevent database write protection exceptions.

## See Also
[[IRIS Role-Based Access Control]] · [[Admin Routes Return 401]]
