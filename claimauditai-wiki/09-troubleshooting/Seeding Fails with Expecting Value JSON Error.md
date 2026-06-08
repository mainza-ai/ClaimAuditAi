# Seeding Fails with Expecting Value JSON Error

> This troubleshooting guide explains why seeding sample data or invoking system administration endpoints returns a client-side JSON parsing error (`Expecting value: line 1 column 1 (char 0)`) and fails to populate the dashboard.

### Symptom
When clicking the **Seed Sample Data** button on the UI, or running the E2E integration test suite, the operation fails with a JSON parsing error:
```json
{"error": "Expecting value: line 1 column 1 (char 0)"}
```
Or the response payload displays raw text preceding the JSON object:
```text
Created table ClaimAudit.ClinicalNotes.
Created HNSW Vector Index on ClaimAudit.ClinicalNotes.
Autoencoder Model: Successfully trained Autoencoder. Normal threshold: 0.020000
NLP model pre-loaded.
{"status":"success","message":"Successfully ingested 8 FHIR Claims..."}
```

### Root Cause
The `Engine.Setup()` method printed status logs directly to the active output device using `Write` statements (e.g. `Write "Created table...", !`). 

When `LoadSampleData()` is executed from a REST API context (such as the HTTP POST `/api/samples/load` route), the active output device is the `%response` HTTP stream. The `Write` statements print raw text directly into the HTTP response body *before* the router writes the final JSON response. This corrupts the payload structure, resulting in an invalid JSON payload that causes the client-side JSON parser to throw an `Expecting value` exception.

### Resolution

#### 1. Implement a Quiet Flag in `Setup`
Update the `Setup` method signature in [Engine.cls](src/cls/ClaimAudit/AI/Engine.cls) to accept a quiet parameter, and wrap all console write statements in conditionals:

```objectscript
ClassMethod Setup(pQuiet As %Boolean = 0) As %Status
{
    Set sc = $$$OK
    Try {
        // ... DB setup logic
        If $$$ISOK(tSC) {
            Do tStatement.%Execute()
            If 'pQuiet Write "Created table ClaimAudit.ClinicalNotes.", !
        }
        // ... repeat for other Write statements
    } Catch ex {
        Set sc = ex.AsStatus()
        If 'pQuiet Write "Setup Error: ", ex.DisplayString(), !
    }
    Quit sc
}
```

#### 2. Call `Setup` in Quiet Mode
Ensure that any runtime calls to `Setup` executed from a REST context (such as the sample data loader in [Router.cls](src/cls/ClaimAudit/REST/Router.cls)) pass `1` (quiet mode):

```objectscript
ClassMethod LoadSampleData() As %Status
{
    // ...
    Set $Namespace = "INTEROP"
    Try {
        Set ^ClaimAuditAI("Seeding") = 1
        // Ensure database tables and indices exist in quiet mode
        Do ##class(ClaimAudit.AI.Engine).Setup(1)
        // ...
```

This ensures that the HTTP response stream is clean and contains only the serialized JSON response object.

## See Also
[[ServiceIdIdx Object Open Failure]] · [[Troubleshooting Overview]] · [[API Endpoints]] · [[Initialization Script]]
