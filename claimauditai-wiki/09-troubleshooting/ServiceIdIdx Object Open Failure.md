# ServiceIdIdx Object Open Failure

> This troubleshooting guide explains why calling sample data loading or querying FHIR details returns the error `ERROR #5770: Object open failed because 'ServiceIdIdx' key value of '' was not found`.

### Symptom
When calling `LoadSampleData()` or sending requests, the database returns a JSON error or CLI stack trace:
```json
{"error":"ERROR #5770: Object open failed because 'ServiceIdIdx' key value of '' was not found"}
```

### Cause
This error indicates that the FHIR server service registry endpoint (such as `/fhir/r4`) could not be resolved in the current namespace context. This happens in two scenarios:

1. **FHIR Server is Not Provisioned:**
   The FHIR server instance at `/fhir/r4` has not been installed/created in the namespace. See [[FHIR Server 404.md]] to check if the endpoint is created.
   
2. **Wrong Namespace Execution:**
   The FHIR server is namespace-scoped (installed in the `INTEROP` namespace). If you run the sample data loader command in the default namespace (such as `USER` or `%SYS`):
   ```bash
   docker exec -it claimaudit-iris iris session IRIS "##class(ClaimAudit.REST.Router).LoadSampleData()"
   ```
   without specifying the `-U INTEROP` namespace switch, the method resolves the class but tries to locate `/fhir/r4` in `USER`, which has no such endpoint registered, causing `EnsureInstance` to fail.

### Resolution

#### 1. Use the Correct Namespace CLI Switch
Always run database CLI commands with the `-U INTEROP` parameter to target the correct namespace scope:
```bash
docker exec -it claimaudit-iris iris session IRIS -U INTEROP "##class(ClaimAudit.REST.Router).LoadSampleData()"
```

#### 2. Verify Namespace-Safe Code is Deployed
The system has been hardened by wrapping the `LoadSampleData` method in [Router.cls](src/cls/ClaimAudit/REST/Router.cls) with a scoped namespace switch:
```objectscript
ClassMethod LoadSampleData() As %Status
{
    // Programmatically switch namespace to INTEROP to make this CLI-safe
    New $Namespace
    Set $Namespace = "INTEROP"
    Try {
        ...
```
This guarantees that even if a developer calls the command from `USER`, the runtime automatically redirects processing to `INTEROP` in memory.

## See Also
[[FHIR Server 404.md]] · [[Initialization Script]] · [[Installation Guide]]
