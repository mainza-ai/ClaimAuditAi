# LLM Router Architecture

> The LLM Router provides multi-provider failover, rate limiting, response caching, and streaming for all AI-generated adjudication reports and chat interactions.

The router (`llm_router.py`) is the central hub for all LLM communication. It normalizes four providers behind a single OpenAI-compatible interface, handles retries with exponential backoff, and falls back through the provider chain when a service is unavailable.

## Supported Providers

| Provider | Env Key | Setting Key | Default Model |
|----------|---------|-------------|---------------|
| **NVIDIA** (`nvidia`) | `NVIDIA_API_KEY` | `nvidiaApiKey` | `nvidia/nemotron-3-super-120b-a12b` |
| **Ollama** (`ollama`) | `OLLAMA_BASE_URL` | `ollamaBaseUrl` | `llama3` |
| **OpenAI** (`openai`) | `OPENAI_API_KEY` | `openaiApiKey` | `gpt-4` |
| **OpenRouter** (`openrouter`) | `OPENROUTER_API_KEY` | `openrouterApiKey` | `google/gemini-2.5-pro` |

All clients are created via the OpenAI Python SDK, since all four providers expose an OpenAI-compatible `/v1/chat/completions` endpoint.

## Provider Fallback Chain

The `chat()` function implements a two-level resilience pattern:

1. **Provider queue**: The primary provider (from settings or `LLM_PROVIDER` env var) is tried first, then all other configured providers are appended as fallbacks.
2. **Per-provider retries**: Each provider is retried up to `retryCount` + 1 times with exponential backoff (`1s, 2s, 4s, ...`).

If a provider lacks API credentials, it is silently skipped. If all providers fail and the request is a non-tool generation (e.g. an adjudication report), a rule-based fallback report is generated instead of raising an error.

```
Request
   │
   ▼
┌─────────────────────────────────────┐
│ Check rate limit (rateLimitPerMin)  │
└─────────────────────────────────────┘
   │
   ▼
┌─────────────────────────────────────┐
│ Check response cache (cacheTTL)     │
└─────────────────────────────────────┘
   │ (miss)
   ▼
┌─────────────────────────────────────┐
│ Try: primary provider               │
│   ├─ success ──► return            │
│   └─ failure ──► retry × N         │
│                    └─ fallback next │
│                                     │
│ Try: fallback provider              │
│   ├─ success ──► return            │
│   └─ failure ──► retry × N         │
│                    └─ fallback next │
│                                     │
│ ...                                 │
│                                     │
│ All failed → rule-based fallback    │
└─────────────────────────────────────┘
```

## Rate Limiting

The router maintains a thread-safe sliding window rate limiter:

| Setting | Default | Source |
|---------|---------|--------|
| `rateLimitPerMin` | `120` | `.llm_settings.json` via UI or Settings API |

Timestamps from the last 60 seconds are tracked in `_request_timestamps`. If the count exceeds the limit, a `RuntimeError` is raised. The check runs before each LLM API call.

## Response Caching

Non-tool LLM responses (adjudication reports, summaries) are cached in a bounded in-memory `OrderedDict` LRU cache keyed by the full prompt parameters:

| Setting | Default | Source |
|---------|---------|--------|
| `cacheTTL` | `86400` (24h) | `.llm_settings.json` |
| `MAX_CACHE_SIZE` | `500` | Hard-coded in `llm_router.py` |

The cache uses a **least-recently-used (LRU) eviction policy**: when the cache exceeds 500 entries, the oldest entry is removed (`popitem(last=False)`). On cache hit, the entry is moved to the end (`move_to_end()`) to preserve recency ordering. This prevents unbounded memory growth under sustained production load.

The cache is invalidated by:
- `invalidate_llm_cache()` — clears cached responses only
- `invalidate_client_cache()` — clears cached OpenAI clients and all responses (called after provider/settings change)

Tool-calling responses are not cached because they depend on the dynamic state of tool execution results.

## Chat Streaming

The `chat_stream()` generator yields token chunks via OpenAI SSE streaming:

```
Client (SSE) ──► IRIS ──► llm_router.chat_stream()
                              │
                              ▼
                         OpenAI SDK
                         stream=True
                              │
                              ▼
                         Token chunks
                         → yield to IRIS
                         → forwarded to client
```

The ObjectScript `ChatStream` endpoint buffers these chunks into 80-character SSE `data:` lines for compatibility with the FHIR gateway infrastructure.

## Key Functions

| Function | Purpose |
|----------|---------|
| `chat()` | Core LLM call with fallback, retry, rate limiting, caching |
| `generate()` | Adjudication report generation (wraps `chat`) |
| `chat_stream()` | Streaming token generator for chat UI |
| `run_chat_agent()` | Multi-step ReAct agent loop with tool execution (see [[Agent Tool Registry]]) |
| `summarize_user_reason()` | Condenses auditor rationale into a 2-4 sentence ledger entry |
| `list_ollama_models()` | Queries Ollama `/api/tags` for available local models |
| `parse_disposition()` | Extracts structured Tier 1/2/3 scores and flags from LLM markdown output |
| `invalid_llm_cache()` | Clears cached completions |
| `invalid_client_cache()` | Clears cached clients and completions |

## Settings Persistence

Settings are stored in `/home/irisowner/dev/.llm_settings.json` and loaded via `_load_settings()` with mtime-based cache invalidation. The file is written by the `POST /settings/llm` API endpoint and read by Embedded Python on each LLM call.

```json
{
  "provider": "nvidia",
  "nvidiaApiKey": "...",
  "nvidiaModel": "nvidia/nemotron-3-super-120b-a12b",
  "rateLimitPerMin": 120,
  "cacheTTL": 86400,
  "timeout": 300.0,
  "retryCount": 3
}
```

## See Also

[[Agent Tool Registry]] · [[Orchestration - AI Hub]] · [[Environment Variables Reference]] · [[API Endpoints]]
