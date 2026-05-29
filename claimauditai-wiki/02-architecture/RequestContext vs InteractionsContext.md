# RequestContext vs InteractionsContext

> InterSystems FHIR Server separates execution memory into RequestContext (global REST parameters) and InteractionsContext (internal storage session variables), requiring careful thread-safe flag handling.

When a client submits a FHIR request, the platform allocates memory parameters for the REST request context (`HS.FHIRServer.API.Data.Request`). Internal dispatches via `pFHIRService.DispatchRequest()` inherit or clone sections of this environment.

To prevent recursive loops (where creating secondary resources like `ClaimResponse` triggers the `Claim` interceptor again), ClaimAuditAI isolates execution variables. It wipes thread flags immediately upon entering the `OnAfterRequest` block and strictly guards interceptions to requests where `Type = "Claim"`.

```objectscript
// Inside OnAfterRequest
If (pFHIRRequest.Type = "Claim") && ($Get(^||ClaimAuditFlag("flagged")) = 1) {
    // Retrieve variables
    Set summary = $Get(^||ClaimAuditFlag("summary"))
    Set score = $Get(^||ClaimAuditFlag("score"))
    // Kill flags instantly before calling DispatchRequest internally
    Kill ^||ClaimAuditFlag
    ...
}
```

> [!danger]
> Failing to clear the thread flag `^||ClaimAuditFlag` before executing internal resource creation requests results in an infinite call loop, eventually exhausting the IRIS call stack and crashing the worker process.

## Key Details
- **Thread Flag Global**: `^||ClaimAuditFlag` (Process-Private Global)
- **Recursion Guard**: Fast-kill variable pattern at the top of mutated handler blocks.
- **Request Type Restriction**: Interception checks are strictly bounded to `pFHIRRequest.Type = "Claim"`.
- **Memory Lifetime**: Automatically garbage collected by the IRIS kernel when the active CSP connection closes.

## See Also
[[FHIR Interception Strategy]] · [[Data Flow]] · [[InteractionsStrategy Not Firing]]