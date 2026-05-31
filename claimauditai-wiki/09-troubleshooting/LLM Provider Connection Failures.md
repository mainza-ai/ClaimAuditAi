# LLM Provider Connection Failures

> The LLM adjudication engine fails with "Python exception" when `NVIDIA_API_KEY` is not accessible from Embedded Python, or when runtime provider settings are out of sync with environment variables.

### Symptom
- Claim detail shows: "Full LLM adjudication report not available. The Python agent could not connect to the LLM provider..."
- Disposition text contains: `PYTHON EXCEPTION` or `ValueError: NVIDIA_API_KEY is not configured`
- The `agent_orchestrator.py` `GenerateHoldSummary()` raises `RuntimeError`
- Chat assistant returns errors instead of answers

### Root Causes

#### 1. NVIDIA_API_KEY Not Visible to Embedded Python

Even though `NVIDIA_API_KEY` is set in `docker-compose.yml` `environment:` and visible via `docker exec claimaudit-iris env | grep NVIDIA_API_KEY`, Embedded Python's `os.environ.get()` returns `None`. This is because IRIS uses a separate process model where environment variables from the container shell are not inherited by the IRIS Embedded Python runtime.

**Fix:** Explicitly set the environment variable in ObjectScript before calling Python:

```objectscript
Do $SYSTEM.Process.Environment.Set("NVIDIA_API_KEY", "nvapi-...")
```

Or set it in the Python module itself using a settings file.

#### 2. Runtime Provider Switching via .llm_settings.json

The `llm_router.py` module (rewritten) supports runtime overrides via `/home/irisowner/dev/.llm_settings.json`. This file is read by `_load_settings()` and takes precedence over environment variables:

```python
def _load_settings() -> dict:
    settings_path = "/home/irisowner/dev/.llm_settings.json"
    if os.path.exists(settings_path):
        try:
            with open(settings_path) as f:
                return json.load(f)
        except Exception:
            pass
    return {}
```

The settings endpoint `POST /api/settings/llm` writes to this file. If the file contains invalid JSON or is missing, the system falls back to environment variables.

#### 3. Provider Switching Without Restart

The `.llm_settings.json` file is re-read on every `_get_client_and_model()` call, so provider changes take effect immediately — no IRIS restart required. However, if the API key in the settings file is wrong, you'll get API errors rather than Python exceptions.

### Resolution

#### Check Current Provider Configuration
```bash
curl http://localhost:3000/api/settings/llm
```

#### Update Provider via API
```bash
curl -X POST http://localhost:3000/api/settings/llm \
  -H "Content-Type: application/json" \
  -d '{"provider": "nvidia", "nvidiaApiKey": "nvapi-..."}'
```

#### Fallback: Set via IRIS Session
```bash
docker exec claimaudit-iris iris session IRIS -U %SYS <<< 'do $SYSTEM.Process.Environment.Set("NVIDIA_API_KEY", "nvapi-...")'
```

#### Verify Provider Works
```bash
curl -X POST http://localhost:3000/api/chat \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"hello"}],"claimContext":""}'
```

### Architecture

The LLM provider routing now works as follows:

```
llm_router.py
  ├── _load_settings()  →  /home/irisowner/dev/.llm_settings.json
  ├── _get_client_and_model()
  │     ├── settings["nvidiaApiKey"]  ??  os.environ["NVIDIA_API_KEY"]
  │     ├── settings["ollamaBaseUrl"] ??  os.environ["OLLAMA_BASE_URL"]
  │     └── settings["openaiApiKey"]  ??  os.environ["OPENAI_API_KEY"]
  ├── chat()           →  Generic chat (used by POST /api/chat)
  ├── generate()       →  Adjudication report generation
  └── summarize_user_reason()  →  AI rationale summarization
```

`agent_orchestrator.py` uses `llm_router.generate()` instead of creating its own OpenAI client, ensuring all calls route through the same provider-agnostic interface.

## See Also
[[AI Hub Tool Invocation Failures]] · [[Seed Data Disposition Validation]] · [[Embedded Python Import Errors]]
