# FHIR Server 404

> FHIR Server 404 errors occur when the `/api` web application is not registered, the FHIR endpoint is not provisioned, or the database namespace mapping is missing.

### Symptom
- Sending REST requests to `http://localhost:52773/api/*` returns an HTML `404 Not Found` page with IRIS headers (`Expires`, `Cache-Control`, `Pragma`)
- `http://localhost:52773/fhir/r4` also returns 404
- `Security.Applications.Exists("/api")` returns `0`

### Diagnostic Steps
1. **Check `/api` Web App Registration**:
   ```bash
   echo 'zn "%SYS" w ##class(Security.Applications).Exists("/api")' | docker exec -i claimaudit-iris iris session IRIS
   ```
   Returns `0` if not registered.

2. **Check FHIR Server Status**:
   ```bash
   echo 'set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS cnt FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=? AND TABLE_NAME=?","HSFHIR_X0001_S","ClaimResponse") do rs.%Next() w rs.%Get("cnt")' | docker exec -i claimaudit-iris iris session IRIS -U INTEROP
   ```
   Returns `0` if FHIR tables don't exist.

3. **Check Router Class Compilation**:
   ```bash
   echo 'w ##class(ClaimAudit.REST.Router).%ClassName(1)' | docker exec -i claimaudit-iris iris session IRIS -U INTEROP
   ```
   Should return `ClaimAudit.REST.Router`. If it fails, the class wasn't compiled.

### Resolution

#### 1. `/api` Web App Not Registered
The `iris.script` must register the `/api` web application. If it wasn't created during Docker build (due to [[iris.script Indentation Pitfalls]]), create it manually:

```bash
echo 'zn "%SYS" set p("DispatchClass")="ClaimAudit.REST.Router",p("NameSpace")="INTEROP",p("AutheEnabled")=96,p("Recurse")=1,p("MatchRoles")=":%All" do ##class(Security.Applications).Create("/api",.p)' | docker exec -i claimaudit-iris iris session IRIS
```

Then verify: `curl -s http://localhost:52773/api/stats`

#### 2. FHIR Server Not Provisioned
By default, the FHIR server is provisioned during the **Docker build phase** inside `iris.script` to ensure it is always ready on container start. 

However, if you mount external databases or if the installation was skipped (e.g. because `/docker-entrypoint-initdb.d/` script executions are bypassed by the base image when detecting an already initialized state), you can provision it manually:

```bash
docker exec -i claimaudit-iris iris session IRIS -U INTEROP <<< '
  do ##class(HS.FHIRServer.Installer).InstallNamespace()
  set tSC = ##class(HS.FHIRServer.Installer).InstallInstance("/fhir/r4", "ClaimAudit.FHIR.InteractionsStrategy", "hl7.fhir.r4.core@4.0.1")
  if tSC { w "FHIR server created",! } else { w "FHIR server: ",$SYSTEM.Status.GetOneErrorText(tSC),! }
'
```

#### 3. Rebuild with All Fixes
For a permanent fix, rebuild the Docker image with the corrected `iris.script`:

```bash
docker compose build iris --no-cache
docker compose up -d
```

## See Also
[[iris.script Indentation Pitfalls]] · [[Initialization Script]] · [[FHIR Server Provisioning]] · [[Blank UI Due to API Error Responses]]
