import os
import json
import sys
from openai import OpenAI

def clean_non_bmp(text: str) -> str:
    """Removes emojis and other characters outside the Basic Multilingual Plane (BMP)
    to satisfy strict FHIR schema validations in IRIS."""
    return "".join(c for c in text if ord(c) <= 0xFFFF)

def chat(system_prompt: str, messages_json: str) -> str:
    """Route a chat request through the configured LLM provider.
    
    Supports nvidia (default), ollama (local), and openai providers.
    Raises on misconfiguration or connection failure — no silent mock fallbacks.
    """
    provider = os.environ.get("LLM_PROVIDER", "nvidia").lower()

    # Load messages safely
    try:
        messages = json.loads(messages_json)
    except Exception:
        messages = []

    if provider == "nvidia":
        api_key = os.environ.get("NVIDIA_API_KEY", "")
        if not api_key:
            raise ValueError("NVIDIA_API_KEY is not configured in your environment variables.")
        base_url = os.environ.get("NVIDIA_BASE_URL", "https://integrate.api.nvidia.com/v1")
        model = os.environ.get("NVIDIA_MODEL", "nvidia/nemotron-3-super-120b-a12b")
    elif provider == "ollama":
        api_key = "ollama"
        base_url = os.environ.get("OLLAMA_BASE_URL", "http://host.docker.internal:11434/v1")
        model = os.environ.get("OLLAMA_MODEL", "llama3")
    else:  # openai
        api_key = os.environ.get("OPENAI_API_KEY", "")
        if not api_key:
            raise ValueError("OPENAI_API_KEY is not configured in your environment variables.")
        base_url = os.environ.get("OPENAI_BASE_URL", "https://api.openai.com/v1")
        model = os.environ.get("OPENAI_MODEL", "gpt-4")

    try:
        client = OpenAI(api_key=api_key, base_url=base_url)
        full_messages = [{"role": "system", "content": system_prompt}] + messages

        response = client.chat.completions.create(
            model=model,
            messages=full_messages,
            max_tokens=1024,
            temperature=0.3,
            timeout=60.0
        )
        return clean_non_bmp(response.choices[0].message.content)
    except Exception as e:
        sys.stderr.write(f"LLM Chat Connection Error: {str(e)}\n")
        raise RuntimeError(f"LLM Connection Error: {str(e)}")
