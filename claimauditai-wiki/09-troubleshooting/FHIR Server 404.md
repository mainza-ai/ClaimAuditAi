# FHIR Server 404

> FHIR Server 404 errors occur when the operational database namespace or the FHIR endpoint configuration is missing or incorrectly mapped.

### Symptom
Sending REST requests to `http://localhost:52773/interop/fhir/r4` returns an HTTP `404 Not Found` status.

### Diagnostic Steps
1. **Check Database Namespace**: Run this command to verify that the `INTEROP` namespace exists:
   ```bash
   echo 'write $namespace, !' | docker exec -i claimaudit-iris iris session IRIS -U INTEROP
   ```
2. **Inspect Endpoint Registration**: Open the Management Portal and check if the `/interop/fhir/r4` endpoint is registered.

### Resolution
Re-run the namespace and strategy initialization scripts inside the IRIS session to rebuild the endpoint mapping:
```bash
echo 'do $system.OBJ.Load("/home/irisowner/dev/iris/installer.cls", "ck")' | docker exec -i claimaudit-iris iris session IRIS
```

## See Also
[[Troubleshooting Overview]] · [[FHIR Server Provisioning]] · [[Initialization Script]]