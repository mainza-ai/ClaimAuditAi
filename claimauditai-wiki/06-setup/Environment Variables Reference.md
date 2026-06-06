# Environment Variables Reference

> The .env file configures the machine learning models, API gateways, JWT authentication, and FHIR interceptor paths.

The following environment variables configure the system's operational parameters:

## LLM Configuration

| Variable Name | Required | Default Value | Description |
| :--- | :---: | :--- | :--- |
| `LLM_PROVIDER` | Yes | `nvidia` | Defines the LLM engine: `nvidia` (cloud), `ollama` (local), or `openai`. |
| `NVIDIA_API_KEY` | Conditional | — | The API key for Nvidia's high-performance cloud LLM gateway. |
| `NVIDIA_BASE_URL` | No | `https://integrate.api.nvidia.com/v1` | Endpoint URL for the Nvidia API. |
| `NVIDIA_MODEL` | No | `nvidia/nemotron-3-super-120b-a12b` | The LLM model used for authoring hold justifications. |
| `OLLAMA_BASE_URL` | Conditional | `http://host.docker.internal:11434/v1` | Endpoint URL for the local Ollama instance. |
| `OLLAMA_MODEL` | No | `llama3.2:3b-instruct-fp16` | The model used on the local Ollama gateway (recommended: `llama3.2:3b-instruct-fp16` or `granite4.1:3b-bf16`). |
| `OPENAI_API_KEY` | Conditional | — | API key for OpenAI-compatible providers. |
| `OPENAI_BASE_URL` | No | `https://api.openai.com/v1` | Endpoint URL for the OpenAI API. |
| `OPENAI_MODEL` | No | `gpt-4` | The model used on the OpenAI gateway. |
| `CHAT_SYSTEM_CONTEXT` | No | `claimaudit` | System context string for the AI chat assistant. |

## JWT Authentication

| Variable Name | Required | Default Value | Description |
| :--- | :---: | :--- | :--- |
| `JWT_SECRET` | Production | (auto-generated GUID) | 32-byte hex HMAC-SHA256 signing key for HS256 JWT tokens. Generate with `openssl rand -hex 32`. In production, this is required — missing it throws a critical security error and prevents login. |
| `JWT_EXPIRY` | No | `86400` | Token lifetime in seconds (default: 24 hours). |
| `CLAIMAUDIT_ENV` | No | `development` | Environment mode: `development` (allows fallback GUID secret) or `production` (requires `JWT_SECRET`). |

## OIDC / Keycloak Integration

| Variable Name | Required | Default Value | Description |
| :--- | :---: | :--- | :--- |
| `JWKS_URI` | OIDC | — | URL for Keycloak/OIDC public key endpoint (e.g., `http://keycloak:8080/realms/claimaudit/protocol/openid-connect/certs`). Required for RS256 token verification. |
| `JWKS_ISSUER` | OIDC | `https://claimauditai.com/fhir` | Expected `iss` claim value in JWT tokens. |

## FHIR Customization

| Variable Name | Required | Default Value | Description |
| :--- | :---: | :--- | :--- |
| `FHIR_CUSTOMIZATION_PATH` | Yes | `/home/irisowner/dev/src/python` | Target path for the Embedded Python modules inside the container. |
| `FHIR_CUSTOMIZATION_MODULE` | No | `claim_interceptor` | Python module name for claim interception logic. |
| `INTERACTION_PATH` | No | `/home/irisowner/dev/src/python` | Path for the FHIR interaction strategy module. |
| `INTERACTION_MODULE` | No | `claim_interceptor` | Module name for the FHIR interaction strategy. |
| `INTERACTION_CLASS` | No | `ClaimInterceptor` | Class name for the FHIR interaction strategy. |

## Python Dependencies

| Variable Name | Required | Default Value | Description |
| :--- | :---: | :--- | :--- |
| `PYTHON_TARGET_PATH` | No | `/usr/irissys/mgr/python` | Pip install target path — must be added to `sys.path` in `ConfigurePythonPath()` for IRIS Embedded Python to find packages. |

> [!warning]
> Never commit the `.env` file containing your active API keys to public repositories. Ensure `.env` is listed inside your `.gitignore` file. Use `.env.example` as a template with placeholder values.

## Key Details
- **Configuration File Location**: Root folder (`/.env`).
- **Required Variable Check**: Validated during container initialization by the setup scripts.
- **Port Bindings**: Mapped in `docker-compose.yml` to support local container-host networking.
- **JWT Secret in Production**: Must be set as an absolute minimum security requirement. A missing `JWT_SECRET` in production mode throws a hard exception and logs a timestamped error to `^ClaimAuditSecurityError`.
- **HMAC Credential Hashes**: User credentials are stored as HMAC-SHA256 hashes in `^ClaimAuditAI("Users",...)` INTEROP namespace globals (see [[Security Users Validate Crash]]).

## See Also
[[Security Overview]] · [[API Key Handling]] · [[Installation Guide]] · [[SMART on FHIR with Keycloak OAuth2]] · [[Security Users Validate Crash]]
