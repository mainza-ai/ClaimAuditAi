# ServiceIdIdx Object Open Failure & Missing Database Schema Tables

> This troubleshooting guide explains why calling sample data loading or executing claim audits returns errors such as `ERROR #5770: Object open failed because 'ServiceIdIdx' key value of '' was not found`, `Table 'CLAIMAUDIT.CLINICALNOTES' not found`, or `<CLASS DOES NOT EXIST> ... ClaimAudit.Data.GraphStore`.

### Symptoms
When calling `LoadSampleData()` or sending claims, the database returns one of the following errors:
1. `{"error":"ERROR #5770: Object open failed because 'ServiceIdIdx' key value of '' was not found"}`
2. `NLP semantic audit failure: Table 'CLAIMAUDIT.CLINICALNOTES' not found. Claim requires manual adjudication review.`
3. `Adjudication engine failure: <CLASS DOES NOT EXIST> 150 AuditClaim+254^ClaimAudit.AI.Engine.1 ClaimAudit.Data.GraphStore.`

### Cause
These errors indicate that either the FHIR server service registry endpoint (such as `/fhir/r4`), the custom database tables (such as `ClaimAudit.ClinicalNotes`), or custom ObjectScript classes (such as `ClaimAudit.Data.GraphStore`) could not be resolved or located in the current namespace context (`INTEROP`).

This happens due to:
1. **Wrong Namespace Execution:**
   The FHIR server is namespace-scoped. If you run the sample data loader command in the default namespace (such as `USER` or `%SYS`):
   ```bash
   docker exec -it claimaudit-iris iris session IRIS "##class(ClaimAudit.REST.Router).LoadSampleData()"
   ```
   without specifying the `-U INTEROP` namespace switch, the method resolves the class but tries to locate `/fhir/r4` in `USER`, causing `EnsureInstance` to fail with the `ServiceIdIdx` error.

2. **Unprovisioned/Uncompiled Database Schema:**
   The database setup is run at build time (`iris.script`) and startup (`init_iris.sh`). However, in some Docker environments (e.g. clean remote deploys or using persistent empty volumes), the container startup script `/docker-entrypoint-initdb.d/init_iris.sh` is executed. In earlier versions of `init_iris.sh`, classes were compiled individually, and `ClaimAudit.Data.GraphStore` was compiled *after* `Setup()` ran, while other classes were omitted. If ZPM was missing the `<Resource Name="ClaimAudit.Data.PKG"/>` definition in `module.xml`, the database never compiled the GraphStore class, leading to a `<CLASS DOES NOT EXIST>` error during audit ingestion.

3. **Missing ClinicalNotes Table:**
   If the autoencoder or NLP setup was skipped or failed due to compilation ordering issues or missing parameters, the SQL DDL statements creating `ClaimAudit.ClinicalNotes` were not executed, resulting in `Table 'CLAIMAUDIT.CLINICALNOTES' not found` errors at runtime.

### Resolution

#### 1. Use the Correct Namespace Switch
Always run database CLI commands with the `-U INTEROP` parameter to target the correct namespace scope:
```bash
docker exec -it claimaudit-iris iris session IRIS -U INTEROP "##class(ClaimAudit.REST.Router).LoadSampleData()"
```

#### 2. Ensure Namespace-Safe Code is Deployed
Ensure that the `LoadSampleData` method in [Router.cls](src/cls/ClaimAudit/REST/Router.cls) programmatically switches to `INTEROP` first:
```objectscript
ClassMethod LoadSampleData() As %Status
{
    // Programmatically switch namespace to INTEROP to make this CLI-safe
    New $Namespace
    Set $Namespace = "INTEROP"
    Try {
        // Ensure database tables and indices exist
        Do ##class(ClaimAudit.AI.Engine).Setup(1)
        // ...
```

#### 3. Compile Classes Recursively in init_iris.sh and iris.script
Ensure both `iris.script` and `init_iris.sh` compile the entire custom directory recursively using `LoadDir`:
```objectscript
// Compile all custom classes recursively
do $SYSTEM.OBJ.LoadDir("/home/irisowner/dev/src/cls", "ckr", , 1)

// Run Engine.Setup() to create audit tables and train models
do ##class(ClaimAudit.AI.Engine).Setup()
```

#### 4. Register All PKGs in module.xml
Verify that [module.xml](module.xml) includes all custom packages:
```xml
      <Resource Name="ClaimAudit.REST.PKG"/>
      <Resource Name="ClaimAudit.AI.PKG"/>
      <Resource Name="ClaimAudit.FHIR.PKG"/>
      <Resource Name="ClaimAudit.Data.PKG"/>
```

## See Also
[[FHIR Server 404]] · [[Initialization Script]] · [[Installation Guide]] · [[Seeding Fails with Expecting Value JSON Error]]
