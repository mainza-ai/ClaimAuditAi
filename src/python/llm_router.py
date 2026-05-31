import os
import sys
import json
import time
import logging
import urllib.request
import urllib.error

logger = logging.getLogger(__name__)

# LLM client singleton cache
_client_cache = {}
_cache_lock = __import__('threading').Lock()

RETRY_COUNT = 3
RETRY_BASE_DELAY = 1.0  # seconds

def clean_non_bmp(text: str) -> str:
    return "".join(c for c in text if ord(c) <= 0xFFFF)

def _load_settings() -> dict:
    settings_path = "/home/irisowner/dev/.llm_settings.json"
    if os.path.exists(settings_path):
        try:
            with open(settings_path) as f:
                return json.load(f)
        except Exception:
            pass
    return {}

def _get_client_and_model():
    settings = _load_settings()
    provider = settings.get("provider") or os.environ.get("LLM_PROVIDER", "nvidia").strip().lower()

    cache_key = provider
    with _cache_lock:
        if cache_key in _client_cache:
            return _client_cache[cache_key]

    result = _create_client(provider, settings)
    with _cache_lock:
        _client_cache[cache_key] = result
    return result


def _create_client(provider: str, settings: dict):
    if provider == "nvidia":
        from openai import OpenAI
        api_key = settings.get("nvidiaApiKey") or os.environ.get("NVIDIA_API_KEY")
        if not api_key:
            raise ValueError("LLM_PROVIDER is 'nvidia' but NVIDIA_API_KEY is not set.")
        base_url = settings.get("nvidiaBaseUrl") or os.environ.get("NVIDIA_BASE_URL", "https://integrate.api.nvidia.com/v1")
        model = settings.get("nvidiaModel") or os.environ.get("NVIDIA_MODEL", "nvidia/nemotron-3-super-120b-a12b")
        client = OpenAI(api_key=api_key, base_url=base_url)
        return client, model

    elif provider == "ollama":
        from openai import OpenAI
        base_url = settings.get("ollamaBaseUrl") or os.environ.get("OLLAMA_BASE_URL", "http://host.docker.internal:11434/v1")
        model = settings.get("ollamaModel") or os.environ.get("OLLAMA_MODEL", "llama3")
        client = OpenAI(api_key="ollama", base_url=base_url)
        return client, model

    elif provider == "openai":
        from openai import OpenAI
        api_key = settings.get("openaiApiKey") or os.environ.get("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("LLM_PROVIDER is 'openai' but OPENAI_API_KEY is not set.")
        base_url = settings.get("openaiBaseUrl") or os.environ.get("OPENAI_BASE_URL", "https://api.openai.com/v1")
        model = settings.get("openaiModel") or os.environ.get("OPENAI_MODEL", "gpt-4")
        client = OpenAI(api_key=api_key, base_url=base_url)
        return client, model

    else:
        raise ValueError(f"Unknown LLM_PROVIDER '{provider}'. Valid values: nvidia, ollama, openai")


def chat(system_prompt: str, messages_json: str, max_tokens: int = 1024) -> str:
    last_error = None
    for attempt in range(RETRY_COUNT + 1):
        try:
            client, model = _get_client_and_model()
            try:
                messages = json.loads(messages_json)
            except Exception:
                messages = []
            full_messages = [{"role": "system", "content": system_prompt}] + messages
            response = client.chat.completions.create(
                model=model,
                messages=full_messages,
                max_tokens=max_tokens,
                temperature=0.3,
                timeout=60.0,
            )
            if not response.choices:
                raise ValueError("LLM returned empty response — no choices available")
            return clean_non_bmp(response.choices[0].message.content)
        except Exception as e:
            last_error = e
            if attempt < RETRY_COUNT:
                delay = RETRY_BASE_DELAY * (2 ** attempt)
                logger.warning(f"LLM attempt {attempt + 1} failed: {e}. Retrying in {delay:.1f}s...")
                time.sleep(delay)
            else:
                logger.error(f"LLM failed after {RETRY_COUNT + 1} attempts: {e}")
    raise RuntimeError(f"LLM request failed after {RETRY_COUNT + 1} attempts: {last_error}")


def invalidate_client_cache():
    """Clear cached LLM clients — call after settings change."""
    with _cache_lock:
        _client_cache.clear()

def generate(prompt: str, max_tokens: int = 2048) -> str:
    return chat(
        system_prompt="You are a healthcare payment integrity AI. Generate precise, structured, clinically accurate audit reports in markdown format. Always include sections for Tier 1, Tier 2, Tier 3 findings, and a final Risk Score summary.",
        messages_json=json.dumps([{"role": "user", "content": prompt}]),
        max_tokens=max_tokens,
    )


def chat_stream(system_prompt: str, messages_json: str, max_tokens: int = 1024):
    """Generator that yields streaming chunks via OpenAI SSE for IRIS SSE passthrough.
    Each yielded string is a complete SSE 'data: ...' line."""
    client, model = _get_client_and_model()
    try:
        messages_list = json.loads(messages_json)
    except Exception:
        messages_list = []

    full_messages = [{"role": "system", "content": system_prompt}] + messages_list

    try:
        stream = client.chat.completions.create(
            model=model,
            messages=full_messages,
            max_tokens=max_tokens,
            temperature=0.3,
            timeout=60.0,
            stream=True,
        )
        for chunk in stream:
            if chunk.choices and chunk.choices[0].delta.content:
                content = clean_non_bmp(chunk.choices[0].delta.content)
                if content:
                    yield content
    except Exception as e:
        yield f"\n\n[Streaming error: {str(e)}]"

def summarize_user_reason(action: str, user_text: str) -> str:
    action_labels = {
        "approve": "approval override",
        "escalate": "escalation to director review",
        "reject": "claim rejection",
    }
    label = action_labels.get(action, action)
    system = "You are a healthcare compliance documentation assistant. Summarize the following auditor rationale into a concise, professional 2-4 sentence note suitable for a formal audit ledger. Use third-person voice. Do not invent details not present in the input. Output only the summary — no preamble, no labels."
    user_msg = f"Auditor action: {label}\nAuditor's stated reason: {user_text}"
    return chat(system_prompt=system, messages_json=json.dumps([{"role": "user", "content": user_msg}]), max_tokens=256)

def list_ollama_models(base_url: str = None) -> list:
    url = (base_url or os.environ.get("OLLAMA_BASE_URL", "http://host.docker.internal:11434"))
    if url.endswith("/v1"):
        url = url[:-3]
    url = url.rstrip("/")
    try:
        req = urllib.request.Request(f"{url}/api/tags")
        with urllib.request.urlopen(req, timeout=3) as resp:
            data = json.loads(resp.read())
            return [m["name"] for m in data.get("models", [])]
    except Exception as exc:
        logger.warning(f"Could not reach Ollama at {url}: {exc}")
        return []
