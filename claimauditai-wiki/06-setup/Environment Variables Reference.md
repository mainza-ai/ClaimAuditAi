# Environment Variables Reference

> The .env file configures the machine learning models, API gateways, and FHIR interceptor paths.

The following environment variables configure the system's operational parameters:

| Variable Name | Required | Default Value | Description |
| :--- | :---: | :--- | :--- |
| `LLM_PROVIDER` | Yes | `nvidia` | Defines the LLM engine: `nvidia` (cloud), `ollama` (local), or `openai`. |
| `NVIDIA_API_KEY` | Conditional | `nvapi-...` | The API key for Nvidia's high-performance cloud LLM gateway. |
| `NVIDIA_BASE_URL` | No | `https://integrate.api.nvidia.com/v1` | Endpoint URL for the Nvidia API. |
| `NVIDIA_MODEL` | No | `z-ai/glm-5.1` | The LLM model used for authoring hold justifications. |
| `OLLAMA_BASE_URL` | Conditional | `http://host.docker.internal:11434/v1` | Endpoint URL for the local Ollama instance. |
| `OLLAMA_MODEL` | No | `llama3` | The model used on the local Ollama gateway. |
| `FHIR_CUSTOMIZATION_PATH` | Yes | `/home/irisowner/dev/src/python` | Target path for the Embedded Python modules inside the container. |

> [!warning]
> Never commit the `.env` file containing your active API keys to public repositories. Ensure `.env` is listed inside your `.gitignore` file.

## Key Details
- **Configuration File Location**: Root folder (`/.env`).
- **Required Variable Check**: Validated during container initialization by the setup scripts.
- **Port Bindings**: Mapped in `docker-compose.yml` to support local container-host networking.

## See Also
[[Security Overview]] · [[API Key Handling]] · [[Installation Guide]]