# FHIR Interception Strategy

> The FHIR interception strategy is implemented by overriding key lifecycle methods of the HS.FHIRServer storage architecture using custom Interactions and RepoManager classes.

To execute payment integrity audits pre-payment, ClaimAuditAI overrides the default FHIR interactions layer. This is achieved by creating:
1. `ClaimAudit.FHIR.RepoManager`: Specifies our custom interactions strategy.
2. `ClaimAudit.FHIR.InteractionsStrategy`: Binds the strategy key.
3. `ClaimAudit.FHIR.Interactions`: Subclasses the default JSON storage interactions and overrides the execution hooks.

```objectscript
Class ClaimAudit.FHIR.Interactions Extends HS.FHIRServer.Storage.Json.Interactions
{
    Method OnBeforeRequest(pFHIRService As HS.FHIRServer.API.Service, pFHIRRequest As HS.FHIRServer.API.Data.Request, pTimeout As %Integer)
    {
        If pFHIRRequest.Type = "Claim" { Kill ^||ClaimAuditFlag }
        Do ##super(pFHIRService, pFHIRRequest, pTimeout)
    }
}
```

> [!important]
> The custom Interactions class must inherit from `HS.FHIRServer.Storage.Json.Interactions` rather than the abstract base interactions class to preserve the built-in JSON indexing and serialization capabilities.

## Key Details
- **Interactions Base Class**: `HS.FHIRServer.Storage.Json.Interactions`
- **RepoManager Base Class**: `HS.FHIRServer.Storage.Json.RepoManager`
- **Key Strategy Override**: `OnBeforeRequest` and `OnAfterRequest`
- **Gateway Binding**: Set via the StrategyKey parameter inside `RepoManager`.

## See Also
[[System Architecture Overview]] · [[RequestContext vs InteractionsContext]] · [[InteractionsStrategy Not Firing]]