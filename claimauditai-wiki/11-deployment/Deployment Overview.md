# Deployment Overview

> Deployment involves packaging the application using the InterSystems Package Manager (ZPM) and staging the system in secure cloud environments.

ClaimAuditAI is designed to be highly portable. Deploying the platform to staging or production involves:

```
Local Codebase ──> [ZPM Package] ──> module.xml Compilation ──> Cloud Container (AWS/GCP)
```

1. **ZPM Packaging**: Compiles code into a redistributable package using `module.xml`.
2. **Cloud Container Staging**: Provisions the system in cloud environments (such as AWS or GCP) using our multi-stage Docker configurations.
3. **Public Gateway Setup**: Secures the `/fhir/r4` endpoint behind cloud API gateways.

This architecture ensures that the platform is easy to deploy, scale, and manage across diverse cloud environments.

## Key Details
- **Packaging Format**: IPM / ZPM (InterSystems Package Manager).
- **ZPM Build Command**: `zpm "load /home/irisowner/dev"`
- **Cloud Infrastructure**: Scalable container instances running on AWS ECS or Google Cloud Run.
- **Volume Mappings**: Mounts persistence directories to survive container restarts.

## See Also
[[ZPM Packaging and module.xml]] · [[Online Demo Hosting]] · [[Developer Article Checklist]]