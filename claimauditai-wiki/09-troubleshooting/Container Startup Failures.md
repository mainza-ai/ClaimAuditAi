# Container Startup Failures

> Container startup failures occur due to insufficient VM memory allocations or folder permission locks inside the Docker engine.

### Symptom
The Docker container crashes or hangs during `docker-compose up -d --build`, throwing errors like `OOM Killed` or `Permission Denied` when writing to the database directories.

### Diagnostic Steps
1. **Check Docker VM Memory**: Run this command to inspect Docker VM memory limits:
   ```bash
   docker info | grep "Total Memory"
   ```
2. **Inspect Container Logs**: Run this command to inspect the startup logs:
   ```bash
   docker logs claimaudit-iris
   ```

### Resolution
1. **Increase Allocated RAM**: Open Docker Desktop settings, navigate to **Resources** -> **Advanced**, and increase allocated memory to at least **6 GB**.
2. **Reset Folder Permissions**: If your operating system locked access to the project folder, reset file permissions:
   ```bash
   chmod -R 777 /Users/mck/Desktop/claimauditai
   ```

## See Also
[[Troubleshooting Overview]] · [[Installation Guide]] · [[Docker Configuration]]