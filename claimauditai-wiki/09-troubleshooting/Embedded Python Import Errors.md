# Embedded Python Import Errors

> Embedded Python import errors occur when the running CSP gateway worker process caches old Python modules in system memory.

### Symptom
You modify python files in your local workspace, but the running IRIS instance continues to execute the old version of the code.

### Diagnostic Steps
1. **Check Python Paths**: Verify that your custom modules are located in the registered python search paths.
2. **Inspect Caching Behavior**: Changes to Python code are not reflected immediately due to caching in the active CSP worker processes.

### Resolution
Execute the cache flush command inside the `%SYS` namespace to terminate active worker jobs and force the database to reload your Python modules:
```bash
echo 'zn "%SYS" do KillAllCSPJobs^%SYS.cspServer2()' | docker exec -i claimaudit-iris iris session IRIS
```

## See Also
[[Troubleshooting Overview]] · [[Embedded Python in IRIS]] · [[Docker Configuration]]