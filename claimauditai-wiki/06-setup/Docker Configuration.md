# Docker Configuration

> The Docker configuration builds the container environment, installs system-level Python packages, and mounts codebase volumes.

The system uses a multi-stage Docker environment designed to run both database-native ObjectScript and Embedded Python machine learning models:

```
Base Image: intersystemsdc/irishealth-community:latest
   │
   ▼   [System Level Setup]
Install Python3 & Pip
   │
   ▼   [Dependency Installation]
Install PyTorch, SentenceTransformers, NetworkX, and OpenAI
   │
   ▼   [Configuration Merges]
Apply merge.cpf & Mount /home/irisowner/dev Codebase Volume
```

> [!important]
> The container mounts your local codebase volume directly to `/home/irisowner/dev` inside the container, allowing you to edit files on your host machine and see the changes immediately in the running IRIS instance.

## Key Details
- **Base Image**: `intersystemsdc/irishealth-community:latest`
- **Volume Mount Path**: `/home/irisowner/dev` (mapped to host project root).
- **Management Web Port / REST API**: Mapped from container `52773` to host `52773`.
- **UI Web Port**: Mapped from container `80` to host `3000`.

## See Also
[[Prerequisites]] · [[Installation Guide]] · [[Initialization Script]]