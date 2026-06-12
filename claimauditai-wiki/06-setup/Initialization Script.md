# Initialization Script

> The initialization process involves both a **build-time script** (`iris.script`) and a **runtime script** (`init_iris.sh`). The build script compiles classes and registers the web application; the runtime script provisions the FHIR server and trains ML models.

## Build-Time: `iris.script`

The build process is automated using the `iris.script` manifest, which executes during the Docker build (`RUN iris start IRIS && iris session IRIS < iris.script && iris stop IRIS quietly`):

```
[iris.script] ──> Install ZPM ──> Create INTEROP Namespace ──> Create Roles & Users (%SYS)
                       │
                       v
               Store Credential Hashes
               (^ClaimAuditAI globals in INTEROP)
                       │
                       v
               Compile All Custom Classes Recursively
               (via LoadDir in INTEROP)
                       │
                       v
               Provision FHIR Server & Setup DB
               (InstallInstance & Engine.Setup)
                       │
                       v
               Register /api Web Application
                       │
                       v
               Load ZPM Module (module.xml)
               (Includes REST, AI, FHIR, and Data packages)
```

### Credential Hash Storage

During the build phase, `iris.script` creates five users in the `%SYS` namespace (`admin`, `auditor`, `specialist`, `director`, `viewer`) then switches to `INTEROP` and stores HMAC-SHA256 credential hashes + roles in local globals:

```objectscript
zn "INTEROP"
Set tSalt = "ClaimAuditAI_Salt"
Set ^ClaimAuditAI("Users","admin","hash") = $SYSTEM.Encryption.HMACSHA(256, "ClaimAuditAdmin2026!", tSalt)
Set ^ClaimAuditAI("Users","admin","fullName") = "ClaimAuditAI Admin"
Set ^ClaimAuditAI("Users","admin","roles","Admin") = ""
; ... same for auditor, specialist, director, viewer
```

This is critical: the CSP Gateway dispatches REST requests as `UnknownUser` — a user without `%SYS` database access. Storing credentials in INTEROP globals allows the `Login()` method to validate passwords without namespace switching or `%SYS` permissions. See [[Security Users Validate Crash]] for the full architecture.

### Critical Rules for `iris.script`

1. **Commands must start at column 0** — any leading whitespace causes the line to be treated as a **continuation** of the previous command, not as a new command. This was the root cause of `/api` web app and FHIR server never being created. (See [[iris.script Indentation Pitfalls]].)

2. **ZPM load must be last** — the `zpm "load...":1:1` command with wait mode may consume subsequent stdin as additional ZPM commands. Always place it right before `halt`.

3. **Classes and Tables are Compiled at Build Time** — All custom classes in `src/cls/` are loaded and compiled recursively using `LoadDir("/home/irisowner/dev/src/cls", "ckr", , 1)`. The database schema tables, indices, and vector tables are then created by executing `do ##class(ClaimAudit.AI.Engine).Setup()`. This ensures the database is fully baked into the Docker image.

## Runtime: `init_iris.sh`

On first container start, the Docker entrypoint executes `init_iris.sh` from `/docker-entrypoint-initdb.d/` (or skips it if persistent database files are detected). This script is a fallback that:

```
[init_iris.sh] ──> Compile FHIR Classes ──> Check FHIR Server
(Interactions.cls,       │
 InteractionsStrategy.cls,│
 RepoManager.cls)         │
                          v
                  InstallInstance("/fhir/r4") ──> FHIR Schema Tables
                          │
                          v
                  Engine.Setup() ──> Custom Tables
                  (ClinicalNotes,        │
                   PatientProjections,   │
                   ProviderProjections,  │
                   ClaimProjections)     v
                                  HNSW Index + Autoencoder
                          │
                          v
                  Compile Router.cls ──> All REST routes available
                  (Includes /system/*  │
                   admin routes)       │
```

The FHIR server is created using `HS.FHIRServer.Installer.InstallInstance` which:
1. Loads FHIR metadata from the `hl7.fhir.r4.core@4.0.1` package
2. Creates HSFHIR_X0001_S.* schema tables (Claim, ClaimResponse, Patient, etc.)
3. Binds the custom `ClaimAudit.FHIR.InteractionsStrategy` to the endpoint

### Idempotency
The runtime script checks if `HSFHIR_X0001_S.ClaimResponse` table exists before creating the FHIR server. This uses SQL bind parameters (`?`) to avoid ObjectScript single-quote consumption issues.

The `Engine.Setup()` call is idempotent — it creates tables only if they don't exist and skips re-training if the autoencoder model file is present.

The Router compilation (`$SYSTEM.OBJ.Load(...)`) always runs to ensure the latest source is compiled, including the full suite of `/system` routes: `/system/status`, `/system/clear`, `/system/upload`, `/system/health`, `/system/users` (GET+POST), `/system/users/:username` (PUT+DELETE), `/system/backup`, `/system/admin-log`, `/system/retrain-model`, `/system/backfill-tier-results`.

## Key Details
- **Build Manifest**: `iris.script` (runs during Docker build)
- **Runtime Manifest**: `init_iris.sh` (runs at container startup)
- **Namespace Creator Class**: `iris/installer.cls`
- **Module Configuration**: `module.xml` with `SourcesRoot=src/cls`
- **ZPM Package Scope**: `ClaimAudit.REST.PKG` + `ClaimAudit.AI.PKG` (excludes FHIR)
- **Router Compilation**: Recompiled at runtime in INTEROP namespace to pick up route changes

## See Also
[[iris.script Indentation Pitfalls]] · [[FHIR Server Provisioning]] · [[Installation Guide]]
