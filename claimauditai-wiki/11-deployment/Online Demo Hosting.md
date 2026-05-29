# Online Demo Hosting

> Online demo hosting deploys the ClaimAuditAI container stack to public cloud instances to support interactive evaluations and reviews.

Deploying public-facing demo environments involves:

```
GitHub Push ──> CI/CD Pipeline ──> AWS EC2 / Google Cloud ──> Reverse Proxy (Nginx) ──> Web Gateway
```

1. **Cloud Provisioning**: Deploying the container stack to a virtual machine (such as AWS EC2 or Google Cloud) with at least **8 GB of RAM**.
2. **Reverse Proxy Configuration**: Configuring Nginx or Apache to proxy public traffic securely to the internal web gateway port (`52773`).
3. **SSL/TLS Certificates**: Installing Let's Encrypt certificates to secure public connections.

This setup allows judges and external reviewers to evaluate our real-time interceptors and FHIR endpoints securely.

## Key Details
- **Cloud VM Recommendations**: AWS EC2 `t3.large` or GCP `e2-standard-2` (Minimum 8 GB RAM).
- **Secure Web Port**: `443` (HTTPS via reverse proxy).
- **Protected Database Ports**: Keep ports `1972` and `52773` closed to public traffic.
- **SSL Certificate Engine**: Let's Encrypt certbot integration.

## See Also
[[Deployment Overview]] · [[Security Overview]] · [[YouTube Walkthrough Checklist]]