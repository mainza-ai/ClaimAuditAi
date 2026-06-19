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

3. **ZPM load PyTorch Dependency Conflict (Massive CUDA Downloads)**:
   * **Symptom:** Docker build takes a very long time (stalling or downloading ~2GB of `nvidia-*` and `torch` packages) during the ZPM package load step (`zpm "load /home/irisowner/dev/"`).
   * **Root Cause:** The InterSystems ZPM package loader automatically installs dependencies from the host-shared `requirements.txt` file. If `torch` is listed in `requirements.txt`, ZPM's pip installer will pull the default CUDA-enabled PyTorch wheel from PyPI, bypassing and overwriting the CPU-only optimized wheel (`torch>=2.1.0 --index-url https://download.pytorch.org/whl/cpu`) pre-installed in the Dockerfile.
   * **Resolution:** Remove `torch` (e.g. `torch>=2.1.0`) from the repository's `requirements.txt`. The Dockerfile already installs the CPU-only PyTorch package explicitly. Removing it from `requirements.txt` stops ZPM from re-downloading CUDA wheels while keeping the pre-installed CPU version active.

## See Also
[[Troubleshooting Overview]] · [[Installation Guide]] · [[Docker Configuration]] · [[iris.script Indentation Pitfalls]]