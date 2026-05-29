# FHIR Server Provisioning

> The FHIR server configuration provisions the /interop/fhir/r4 endpoint and registers our custom Interactions Strategy.

The FHIR server runs in the `INTEROP` namespace. During the automated initialization process, the server is configured to use our custom classes instead of the default ones:

```
Default: HS.FHIRServer.Storage.Json.RepoManager ──> Default Server Storage
Modern:  ClaimAudit.FHIR.RepoManager            ──> Intercepts Claims pre-commit
```

### Manual Audit Portal Verification Paths
If you need to verify or configure endpoints manually, use the **IRIS Management Portal**:
1. Open the Web Portal: `http://localhost:52773/csp/sys/UtilHome.csp`
2. Navigate to: **Health** -> **FHIR Support** -> **FHIR Configuration**
3. Select Namespace: `INTEROP`
4. Assert Strategy Key: `ClaimAudit.FHIR.InteractionsStrategy` is bound to the endpoint `/interop/fhir/r4`.

## Key Details
- **Operational Namespace**: `INTEROP`
- **Endpoint Path**: `/interop/fhir/r4`
- **Interactions Strategy Key**: `ClaimAudit.FHIR.InteractionsStrategy`
- **Custom RepoManager Class**: `ClaimAudit.FHIR.RepoManager`

## See Also
[[FHIR Interception Strategy]] · [[Installation Guide]] · [[FHIR Server 404]]