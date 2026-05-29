# API Key Handling

> API keys and gateway credentials must be managed securely using local environment files that are isolated from public code repositories.

All external credentials (such as your Nvidia API key) are stored in the local `.env` file, which is loaded into the container at startup by `docker-compose.yml`:

```
.env (Git-Ignored) ──> Loaded via env_file in docker-compose ──> Accessible inside Container
```

> [!danger]
> Never commit your `.env` file containing active API keys to public repositories. Ensure that `.env` is listed inside your `.gitignore` file to prevent accidental credentials leaks.

## Key Details
- **Configuration File**: Root directory `.env` file.
- **Git Exclusion**: Configured in `.gitignore` to prevent committing secrets to GitHub.
- **Container Path**: Environment variables are mapped directly to the active database process context.
- **Credential Scopes**: Restrict your Nvidia API keys to the specific models used by the orchestrator.

## See Also
[[Security Overview]] · [[Environment Variables Reference]] · [[PHI and LLM Boundary]]