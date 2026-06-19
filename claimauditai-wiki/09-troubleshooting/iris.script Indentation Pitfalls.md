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

### Indentation Rules
```
Lines starting at column 0  →  New commands
Lines starting with spaces  →  Continuation of the previous command (unless inside a block)
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

---

### New Pitfalls (Multi-line Blocks & Wrapping)

#### 1. Multi-line Blocks (`Try/Catch` or `If`) in Piped Scripts
When running `iris session IRIS < iris.script` in Docker, the interpreter reads and executes commands line-by-line. Block commands (like `Try { ... }` or multi-line `If { ... }`) that span multiple lines are **not supported** at the interactive terminal prompt. 
* **Symptom:** The build throws `<SYNTAX>` on the opening `Try {` or closing `}` lines, aborts the script, and drops IRIS into an interactive prompt (e.g. `INTEROP>`), causing the Docker build to hang indefinitely.
* **Resolution:** Write commands strictly as single-line statements (e.g., place the entire `if ... { ... }` body on a single line) and avoid `Try/Catch` blocks entirely in piped scripts.

#### 2. Terminal Line Wrapping / Length Limits
Lines exceeding 80 columns may be wrapped or split by the terminal interface or shell redirection, causing commands to execute in fragments. This can split string literals, class names, or arguments.
* **Symptom:** Unexplained `<SYNTAX>` or `<COMMAND>` errors (e.g., `<COMMAND> *Function must return a value` when a split method call doesn't match signatures).
* **Resolution:** Keep command lines short. Store long string parameters in temporary local variables on separate lines before passing them to methods:
  ```objectscript
  set p1 = "/fhir/r4"
  set p2 = "ClaimAudit.FHIR.InteractionsStrategy"
  set p3 = "hl7.fhir.r4.core@4.0.1"
  do ##class(HS.FHIRServer.Installer).InstallInstance(p1,p2,p3)
  ```

---

### Resolution Summary

#### 1. Unindent All Command Lines
Every command in `iris.script` must start at **column 0** (no leading spaces):

```iris.script
// Register the REST Web Application
zn "%SYS"
set name="/api", p("DispatchClass")="ClaimAudit.REST.Router", p("NameSpace")="INTEROP", p("AutheEnabled")=96, p("Recurse")=1, p("MatchRoles")=":%All"
if '##class(Security.Applications).Exists(name) { do ##class(Security.Applications).Create(name, .p) }
halt
```

#### 2. Place ZPM Command Last
The `zpm "load...":1:1` command with wait mode may consume subsequent stdin as additional ZPM commands. Always place it at the **end of the script**, right before `halt`.

#### 3. Verify Build Output
During Docker build, check the iris.script step output for confirmation that each command ran:

```
# Look for these expected outputs:
HS.FHIRServer.Installer:InstallNamespace Scheduled ...
Compiling class ClaimAudit.REST.Router
...
[INTEROP|claim-audit-ai]	Activate SUCCESS
```

If you don't see expected output (e.g., no "Activate SUCCESS"), the commands after that point are likely indented or throwing errors.

### Affected Script Sections
The following sections in `iris.script` were fixed:

| Lines | Purpose | Fix |
|-------|---------|-----|
| 37-44 | FHIR server creation (`InstallInstance`) | Converted to single-line `do` without assignments or block structures |
| 49-58 | Web app registration (`/api`) | Converted to single-line `if` block statement |
| 58 | `halt` | Unindented and kept at EOF |

## See Also
[[FHIR Server 404]] · [[Blank UI Due to API Error Responses]] · [[Initialization Script]] · [[Container Startup Failures]]
