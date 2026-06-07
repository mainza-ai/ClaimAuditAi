# ClaimResponse SQL Column Missing

> SQL queries querying fields like `total` or `extension` directly from `HSFHIR_X0001_S.ClaimResponse` fail because these fields are not projected as SQL columns in the default InterSystems FHIR Server schema database.

### Symptom

Queries targeting the `ClaimResponse` SQL table that attempt to select `total` or `extension` columns crash or return empty/null values, for example:
```sql
SELECT CR.total, CR.extension FROM HSFHIR_X0001_S.ClaimResponse CR
```
This causes endpoints like `/api/claims/held` or `/api/ledger` to return error messages or blank data.

### Root Cause

The InterSystems FHIR Server automatically generates SQL projections for indexed search parameters. Fields such as `total` (billing amount totals) and `extension` (custom metadata arrays) are complex JSON properties or not indexed as standard search parameters. Therefore, they do not exist as SQL columns in the projected tables.

Only search-parameter-indexed properties (e.g., `patient`, `disposition`, `status`) are projected as SQL columns.

### Resolution

Instead of attempting to JOIN and select these non-existent columns in SQL, fetch the FHIR resource dynamically via the FHIR Server's API `DispatchRequest` using the resource ID.

1. Adjust the SQL query to select only the resource key (e.g., `CR.Key`) and indexed fields.
2. Parse the ID from the resource key.
3. Within the cursor/resultset loop, call the FHIR service to load the full JSON resource.
4. Deserialise and read `total` or `extension` dynamically.

```objectscript
// Within the SQL loop:
Set tClaimResponseId = $Piece(tCRKey, "/", 2)
If tClaimResponseId '= "" {
    Try {
        Set tService = ##class(HS.FHIRServer.Service).EnsureInstance("/fhir/r4")
        Set tReqCR = ##class(HS.FHIRServer.API.Data.Request).%New()
        Set tReqCR.RequestMethod = "GET"
        Set tReqCR.RequestPath = "/ClaimResponse/" _ tClaimResponseId
        Set tReqCR.Interaction = "read"
        Set tRespCR = ##class(HS.FHIRServer.API.Data.Response).%New()
        Do tService.DispatchRequest(tReqCR, .tRespCR)
        
        If $IsObject(tRespCR.Json) {
            Set tCRJson = tRespCR.Json
            // Read total dynamically
            Set tTotalJson = tCRJson.total
            // Read extension dynamically
            Set tExtJson = tCRJson.extension
        }
    } Catch {}
}
```

## See Also
[[Claim Amounts Always $0]] · [[FHIR SQL Builder Projection Gaps]]
