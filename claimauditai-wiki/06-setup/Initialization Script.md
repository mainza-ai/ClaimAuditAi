# Initialization Script

> The initialization process involves both a **build-time script** (`iris.script`) and a **runtime script** (`init_iris.sh`). The build script compiles classes and registers the web application; the runtime script provisions the FHIR server and trains ML models.

## Build-Time: `iris.script`

The build process is automated using the `iris.script` manifest, which executes during the Docker build (`RUN iris start IRIS && iris session IRIS < iris.script && iris stop IRIS quietly`):

```
[iris.script] ──> Install ZPM ──> Create INTEROP Namespace
                       │
                       v
               Compile Non-FHIR Classes
               (Router.cls, Engine.cls, Agent.cls)
                       │
                       v
               Register /api Web Application
                       │
                       v
               Load ZPM Module (module.xml)
               (REST.PKG + AI.PKG only; FHIR classes excluded)
```

### Critical Rules for `iris.script`

1. **Commands must start at column 0** — any leading whitespace causes the line to be treated as a **continuation** of the previous command, not as a new command. This was the root cause of `/api` web app and FHIR server never being created. (See [[iris.script Indentation Pitfalls]].)

2. **ZPM load must be last** — the `zpm "load...":1:1` command with wait mode may consume subsequent stdin as additional ZPM commands. Always place it right before `halt`.

3. **FHIR-dependent classes must be excluded** — `Interactions.cls`, `InteractionsStrategy.cls`, and `RepoManager.cls` extend FHIR server framework classes that don't exist at build time. They are compiled at runtime by `init_iris.sh`. The `module.xml` limits ZPM to only `ClaimAudit.REST.PKG` and `ClaimAudit.AI.PKG`.

## Runtime: `init_iris.sh`

On first container start, the Docker entrypoint executes `init_iris.sh` from `/docker-entrypoint-initdb.d/`. This script:

```
[init_iris.sh] ──> Compile FHIR Classes ──> Check FHIR Server
(Interactions.cls,       │
 InteractionsStrategy.cls,│
 RepoManager.cls)         │
                          v
                  InstallInstance("/interop/fhir/r4") ──> FHIR Schema Tables
                          │
                          v
                  Engine.Setup() ──> Custom Tables
                  (ClinicalNotes,        │
                   PatientProjections,   │
                   ProviderProjections,  │
                   ClaimProjections)     v
                                  HNSW Index + Autoencoder
```

The FHIR server is created using `HS.FHIRServer.Installer.InstallInstance` which:
1. Loads FHIR metadata from the `hl7.fhir.r4.core@4.0.1` package
2. Creates HSFHIR_X0001_S.* schema tables (Claim, ClaimResponse, Patient, etc.)
3. Binds the custom `ClaimAudit.FHIR.InteractionsStrategy` to the endpoint

### Idempotency
The runtime script checks if `HSFHIR_X0001_S.ClaimResponse` table exists before creating the FHIR server. This uses SQL bind parameters (`?`) to avoid ObjectScript single-quote consumption issues.

## Key Details
- **Build Manifest**: `iris.script` (runs during Docker build)
- **Runtime Manifest**: `init_iris.sh` (runs at container startup)
- **Namespace Creator Class**: `iris/installer.cls`
- **Module Configuration**: `module.xml` with `SourcesRoot=src/cls`
- **ZPM Package Scope**: `ClaimAudit.REST.PKG` + `ClaimAudit.AI.PKG` (excludes FHIR)

## See Also
[[iris.script Indentation Pitfalls]] · [[FHIR Server Provisioning]] · [[Installation Guide]]
