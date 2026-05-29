# InteractionsStrategy Not Firing

> InteractionsStrategy not firing occurs when your custom strategy classes are not loaded or registered on the active FHIR endpoint.

### Symptom
Submitting anomalous claims returns an HTTP `201 Created` status (accepted normally) instead of a `202 Accepted` hold. No errors are logged, and `^||ClaimAuditFlag` is empty.

### Diagnostic Steps
1. **Verify Strategy Configuration**: Run this SQL query to verify that the custom strategy is bound to the endpoint:
   ```sql
   SELECT Key, StrategyClass FROM HS_FHIRServer.EndpointInfo
   ```
2. **Inspect Database Global Logs**: Check if `^ClaimAuditLog` is populated to confirm the request was processed by the interactions class.

### Resolution
Re-compile the interactions strategy class and clear the gateway worker pool to force workers to load the updated code:
```bash
echo 'do $system.OBJ.Load("/home/irisowner/dev/src/cls/ClaimAudit/FHIR/Interactions.cls", "ck")' | docker exec -i claimaudit-iris iris session IRIS -U INTEROP
echo 'zn "%SYS" do KillAllCSPJobs^%SYS.cspServer2()' | docker exec -i claimaudit-iris iris session IRIS
```

## See Also
[[Troubleshooting Overview]] · [[FHIR Interception Strategy]] · [[RequestContext vs InteractionsContext]]