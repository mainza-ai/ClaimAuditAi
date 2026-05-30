# iris.script Indentation Pitfalls

> Lines in `iris.script` that begin with whitespace are treated as continuations of the preceding command — they never execute as new commands. This caused critical setup steps (web app registration, FHIR server creation) to silently fail.

### Symptom
- `/api` web application does not exist after Docker build (`Security.Applications.Exists("/api") = 0`)
- FHIR server is not provisioned
- API returns HTTP 404 or HTML error page
- The `iris.script` build step in Docker appears to succeed, but key setup steps are missing

### Root Cause
In `iris.script` format, the InterSystems IRIS session interprets lines as follows:

```
Lines starting at column 0  →  New commands
Lines starting with spaces  →  Continuation of the previous command
```

The original `iris.script` had the web application registration code **indented with 4 spaces**:

```iris.script
// Run Engine.Setup() to create audit tables and train models
do ##class(ClaimAudit.AI.Engine).Setup()

// Register the REST Web Application
    zn "%SYS"
    set name="/api", p("DispatchClass")="ClaimAudit.REST.Router", ...
    if '##class(Security.Applications).Exists(name) {
        do ##class(Security.Applications).Create(name, .p)
    }
    
    halt
```

The indented lines after `Engine.Setup()` are treated as **continuations** of the `do ##class...` command, not as new commands. The `zn "%SYS"`, `set name=...`, `halt` never execute. The script reaches EOF without registering the web app or halting.

Similarly, the FHIR server creation code after the `zpm "load..."` command was also indented and never executed.

### Resolution

#### 1. Unindent All Command Lines
Every command in `iris.script` must start at **column 0** (no leading spaces):

```iris.script
// Register the REST Web Application
zn "%SYS"
set name="/api", p("DispatchClass")="ClaimAudit.REST.Router", p("NameSpace")="INTEROP", p("AutheEnabled")=96, p("Recurse")=1, p("MatchRoles")=":%All"
if '##class(Security.Applications).Exists(name) {
    do ##class(Security.Applications).Create(name, .p)
}
halt
```

#### 2. Place ZPM Command Last
The `zpm "load...":1:1` command with wait mode may consume subsequent stdin as additional ZPM commands. Always place it at the **end of the script**, right before `halt`:

```iris.script
// All setup commands first (unindented)
do $SYSTEM.OBJ.Load("...")
set sc = ...
zn "%SYS"
// ...

// ZPM load — must be last
zn "INTEROP"
zpm "load /home/irisowner/dev/ -v":1:1

halt
```

#### 3. Verify Build Output
During Docker build, check the iris.script step output for confirmation that each command ran:

```
# Look for these expected outputs:
HS.FHIRServer.Installer:InstallNamespace Scheduled ...
Compiling class ClaimAudit.REST.Router
...
[INTEROP|claim-audit-ai]	Activate SUCCESS
```

If you don't see expected output (e.g., no "Activate SUCCESS"), the commands after that point are likely indented.

### Affected Script Sections
The following sections in `iris.script` were fixed by removing leading indentation:

| Lines | Purpose | Fix |
|-------|---------|-----|
| 37-44 | FHIR server creation (`InstallInstance`) | Unindented (was continuation of `zpm`) |
| 49-58 | Web app registration (`/api`) | Unindented (was continuation of `Engine.Setup()`) |
| 58 | `halt` | Unindented (was continuation, never executed) |

## See Also
[[FHIR Server 404]] · [[Blank UI Due to API Error Responses]] · [[Initialization Script]]
