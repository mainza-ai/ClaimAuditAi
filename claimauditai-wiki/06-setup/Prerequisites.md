# Prerequisites

> ClaimAuditAI requires a stable Docker environment and a configured API gateway to run its database-native payment integrity engines.

Before installing the platform, ensure your environment meets these hardware and software specifications:

### System Requirements
- **Operating System**: macOS (Intel/Apple Silicon) or Windows 10/11 (Pro/Enterprise with WSL2).
- **Engine Core**: Docker Desktop (version 20.10 or higher) with at least **6 GB of RAM** allocated to the VM.
- **Storage Space**: 15 GB of free solid-state drive space (for storing the container layers and machine learning models).

### API Gateway Credentials
- **LLM Adjudication Gateway**: A valid **Nvidia Integrate API Key** to use the default high-performance cloud `nvidia/nemotron-3-super-120b-a12b` model.
- **Local Fallback Option**: A running local **Ollama** instance serving the `llama3.2:3b-instruct-fp16` (6.4 GB) or `granite4.1:3b-bf16` (6.8 GB) models.

## Key Details
- **Docker VM RAM Allocation**: Minimum 6 GB (Required for local PyTorch and SentenceTransformer execution).
- **Exposed Host Ports**: `1972` (SuperServer), `52773` (Web/Management Portal), `8080` (API Gateway).
- **Default LLM Provider**: `nvidia` (Configurable to `ollama` or `openai` in `.env`).

## See Also
[[Installation Guide]] · [[Environment Variables Reference]] · [[Docker Configuration]]