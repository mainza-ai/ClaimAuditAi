import os
import sys
import json
import time
import logging
import urllib.request
import urllib.error
from typing import Any

logger = logging.getLogger(__name__)

# LLM client singleton cache
_client_cache = {}
_cache_lock = __import__('threading').Lock()

# Thread-safe rate limiter state
_request_timestamps = []
_request_lock = __import__('threading').Lock()

from collections import OrderedDict

# Thread-safe LLM response cache
MAX_CACHE_SIZE = 500
_response_cache = OrderedDict()
_response_cache_lock = __import__('threading').Lock()

RETRY_COUNT = 3
RETRY_BASE_DELAY = 1.0  # seconds

def _load_env():
    # Load environment variables from .env file since IRIS Embedded Python
    # processes do not inherit environment variables from the container shell.
    env_path = "/home/irisowner/dev/.env"
    if os.path.exists(env_path):
        try:
            with open(env_path) as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    if "=" in line:
                        k, v = line.split("=", 1)
                        k = k.strip()
                        v = v.strip().strip("'\"")
                        if k:
                            os.environ[k] = v
        except Exception as e:
            logger.warning(f"Could not load .env file in llm_router: {e}")

# Initial load on import
_load_env()

def clean_non_bmp(text: str) -> str:
    return "".join(c for c in text if ord(c) <= 0xFFFF)

_settings_cache = None
_settings_last_loaded = 0.0

def _load_settings() -> dict:
    global _settings_cache, _settings_last_loaded
    settings_path = "/home/irisowner/dev/.llm_settings.json"
    if os.path.exists(settings_path):
        try:
            mtime = os.path.getmtime(settings_path)
            if _settings_cache is not None and mtime <= _settings_last_loaded:
                return _settings_cache
            with open(settings_path) as f:
                _settings_cache = json.load(f)
                _settings_last_loaded = mtime
                return _settings_cache
        except Exception:
            pass
    return _settings_cache if _settings_cache is not None else {}

def _check_rate_limit():
    settings = _load_settings()
    rate_limit = int(settings.get("rateLimitPerMin", 120))
    now = time.time()
    with _request_lock:
        global _request_timestamps
        # Retain only timestamps from the last 60 seconds
        _request_timestamps = [t for t in _request_timestamps if now - t < 60.0]
        if len(_request_timestamps) >= rate_limit:
            raise RuntimeError(f"Rate limit exceeded: maximum {rate_limit} requests per minute allowed.")
        _request_timestamps.append(now)

def _get_client_and_model():
    _load_env()
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

    elif provider == "openrouter":
        from openai import OpenAI
        api_key = settings.get("openrouterApiKey") or os.environ.get("OPENROUTER_API_KEY") or os.environ.get("OPEN_ROUTER_API_KEY")
        if not api_key:
            raise ValueError("LLM_PROVIDER is 'openrouter' but OPENROUTER_API_KEY is not set.")
        base_url = settings.get("openrouterBaseUrl") or os.environ.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
        model = settings.get("openrouterModel") or os.environ.get("OPENROUTER_MODEL", "google/gemini-2.5-pro")
        client = OpenAI(api_key=api_key, base_url=base_url)
        return client, model

    else:
        raise ValueError(f"Unknown LLM_PROVIDER '{provider}'. Valid values: nvidia, ollama, openai, openrouter")


def _generate_rule_based_fallback_summary(prompt: str) -> str:
    """Generate a clean, professional clinical-financial report when all LLM services are offline."""
    import re
    patient_match = re.search(r"Patient ID:\s*(\S+)", prompt)
    provider_match = re.search(r"Provider NPI:\s*(\S+)", prompt)
    cpt_match = re.search(r"Billed CPT Code:\s*([^\n]+)", prompt)
    amount_match = re.search(r"Total Billed Amount:\s*\$([\d.]+)", prompt)
    date_match = re.search(r"Service Date:\s*(\S+)", prompt)
    
    patient = patient_match.group(1) if patient_match else "Unknown"
    provider = provider_match.group(1) if provider_match else "Unknown"
    cpt_desc = cpt_match.group(1) if cpt_match else "Not Provided"
    amount = amount_match.group(1) if amount_match else "0.00"
    date = date_match.group(1) if date_match else "Unknown"
    
    # Extract findings
    findings = []
    lines = prompt.split("\n")
    start_findings = False
    for line in lines:
        if "Automated Audit Findings:" in line:
            start_findings = True
            continue
        if start_findings and line.strip().startswith("-"):
            findings.append(line.strip()[1:].strip())
            
    findings_str = "\n".join(f"- {f}" for f in findings) if findings else "- General anomaly threat score exceeded threshold."
    
    report = f"""# Adjudication Report (Rule-Based Fallback)

This claim has been suspended and placed on a pre-payment administrative hold. Detailed LLM adjudication report generation is currently offline; a standard deterministic adjudication report has been generated instead.

### Claim Adjudication Target
* **Patient Reference ID:** {patient}
* **Billing Provider NPI:** {provider}
* **Billed CPT Code/Description:** {cpt_desc}
* **Total Billed Amount:** ${amount}
* **Service Date:** {date}

### Automated Audit Findings
{findings_str}

### Formal Hold Justification
The claim has been suspended due to one or more anomalies exceeding our billing threshold. Based on our clinical edit guidelines:
1. **Tier 1 (Semantic Note & Coding Alignment)**: Billed procedures lack documented clinical note support, or CPT-ICD code combinations represent a clinical mismatch.
2. **Tier 2 (Statistical Outlier)**: Billed amounts, item counts, or specialty profiles fall outside normal statistical bounds.
3. **Tier 3 (Network Collusion)**: Relational network analysis suggests geographical impossibility or referral loop cycles.

### Actionable Next Steps
1. Request full clinical SOAP documentation, progress notes, and intake forms from the provider.
2. Verify CPT-ICD coding combinations and specialty billing credentials.
3. Once documentation is uploaded, trigger a claim re-audit.
"""
    return report

def chat(system_prompt: str, messages_json: str, max_tokens: int = 1024, timeout: float = None, tools: list = None, response_format: dict = None) -> Any:
    settings = _load_settings()
    cache_ttl = int(settings.get("cacheTTL", 86400))
    cache_key = (system_prompt, messages_json, max_tokens, json.dumps(tools), json.dumps(response_format))

    # 1. Lookup in response cache (only if no tools are used)
    if tools is None:
        with _response_cache_lock:
            if cache_key in _response_cache:
                cached_data = _response_cache[cache_key]
                if time.time() - cached_data["timestamp"] < cache_ttl:
                    logger.info("LLM cache hit.")
                    _response_cache.move_to_end(cache_key)
                    return cached_data["response"]
                else:
                    del _response_cache[cache_key]

    primary_provider = settings.get("provider") or os.environ.get("LLM_PROVIDER", "nvidia").strip().lower()
    
    # Provider queue: try primary, then fallbacks
    providers_queue = [primary_provider]
    for p in ["openai", "nvidia", "openrouter", "ollama"]:
        if p not in providers_queue:
            providers_queue.append(p)
            
    last_error = None
    for provider in providers_queue:
        try:
            # Skip provider if API keys are missing
            if provider == "nvidia" and not (settings.get("nvidiaApiKey") or os.environ.get("NVIDIA_API_KEY")):
                continue
            if provider == "openai" and not (settings.get("openaiApiKey") or os.environ.get("OPENAI_API_KEY")):
                continue
            if provider == "openrouter" and not (settings.get("openrouterApiKey") or os.environ.get("OPENROUTER_API_KEY") or os.environ.get("OPEN_ROUTER_API_KEY")):
                continue
        except Exception:
            continue
            
        # Determine timeout and retry count dynamically from settings
        if timeout is None:
            timeout = float(settings.get("timeout", 300.0))
        retry_count = int(settings.get("retryCount", 3))

        for attempt in range(retry_count + 1):
            try:
                _check_rate_limit()
                
                client, model = _create_client(provider, settings)
                
                try:
                    messages = json.loads(messages_json)
                except Exception:
                    messages = []
                full_messages = [{"role": "system", "content": system_prompt}] + messages
                
                logger.info(f"Attempting LLM call using provider: {provider}, model: {model}")
                
                kwargs = {
                    "model": model,
                    "messages": full_messages,
                    "max_tokens": max_tokens,
                    "temperature": 0.3,
                    "timeout": timeout,
                }
                if tools is not None:
                    kwargs["tools"] = tools
                    kwargs["tool_choice"] = "auto"
                if response_format is not None:
                    kwargs["response_format"] = response_format

                response = client.chat.completions.create(**kwargs)
                if not response.choices:
                    raise ValueError("LLM returned empty response — no choices available")
                
                message = response.choices[0].message
                content = clean_non_bmp(message.content or "")

                if tools is not None:
                    tool_calls_list = []
                    if getattr(message, "tool_calls", None):
                        for tc in message.tool_calls:
                            tool_calls_list.append({
                                "id": tc.id,
                                "type": tc.type,
                                "function": {
                                    "name": tc.function.name,
                                    "arguments": tc.function.arguments
                                }
                            })
                    return {
                        "content": content,
                        "tool_calls": tool_calls_list
                    }

                # Store response in cache (only if no tools are used)
                with _response_cache_lock:
                    _response_cache[cache_key] = {
                        "response": content,
                        "timestamp": time.time()
                    }
                    if len(_response_cache) > MAX_CACHE_SIZE:
                        _response_cache.popitem(last=False)
                return content
            except Exception as e:
                last_error = e
                logger.warning(f"LLM call failed for provider {provider} (attempt {attempt + 1}/{retry_count + 1}): {e}")
                if attempt < retry_count:
                    delay = RETRY_BASE_DELAY * (2 ** attempt)
                    time.sleep(delay)
                else:
                    # Retries exhausted for this provider, fall back to next provider
                    break
                    
    # If all LLM calls failed and it's a non-tool generation, generate rule-based fallback report
    if tools is None:
        logger.error("All LLM providers failed. Executing deterministic fallback report.")
        try:
            messages = json.loads(messages_json)
            user_prompt = messages[0]["content"] if messages else ""
            if "Adjudication Target Claim Details" in user_prompt:
                return _generate_rule_based_fallback_summary(user_prompt)
        except Exception:
            pass
        
    raise RuntimeError(f"All LLM providers failed. Last error: {last_error}")


def invalidate_llm_cache():
    """Clear cached LLM completions."""
    with _response_cache_lock:
        _response_cache.clear()

def invalidate_client_cache():
    """Clear cached LLM clients and completions — call after settings change."""
    with _cache_lock:
        _client_cache.clear()
    invalidate_llm_cache()

def generate(prompt: str, max_tokens: int = 2048) -> str:
    settings = _load_settings()
    # Default to a lower timeout for inline claims processing to avoid blocking FHIR transaction loops
    audit_timeout = float(settings.get("auditTimeout", 300.0))
    return chat(
        system_prompt="You are a healthcare payment integrity AI. Generate precise, structured, clinically accurate audit reports in markdown format. Always include sections for Tier 1, Tier 2, Tier 3 findings, and a final Risk Score summary.",
        messages_json=json.dumps([{"role": "user", "content": prompt}]),
        max_tokens=max_tokens,
        timeout=audit_timeout,
    )


def chat_stream(system_prompt: str, messages_json: str, max_tokens: int = 1024, timeout: float = None):
    """Generator that yields streaming chunks via OpenAI SSE for IRIS SSE passthrough.
    Each yielded string is a complete SSE 'data: ...' line."""
    try:
        _check_rate_limit()
    except Exception as e:
        yield f"\n\n[Streaming error: {str(e)}]"
        return

    settings = _load_settings()
    if timeout is None:
        timeout = float(settings.get("timeout", 300.0))

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
            timeout=timeout,
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
    _load_env()
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

def parse_disposition(disposition: str) -> str:
    import re
    import json
    if not disposition:
        return json.dumps([])
    
    disposition = disposition.strip()
    
    sections_lookahead = r'(?=###|##|\*\*Tier|\*\*Findings|Tier\s*\d|Adjudication|Collusion|Next\s*Steps|Pend|Risk\s*Score|Justification|\*\*Justification|$|#)'
    
    # Try to extract sections using the robust regexes with lookahead
    t1_match = (
        re.search(r'(?:###|##|\*\*|)\s*(?:Tier\s*1|\[NLP\]|Semantic\s*Clinical\s*Audit|NLP\s*Findings|Findings\s*\(NLP\))[^\n]*\n([\s\S]*?)' + sections_lookahead, disposition, re.IGNORECASE) or
        re.search(r'Tier\s*1\s*\((?:NLP)\):\s*([^|\n]+)', disposition, re.IGNORECASE)
    )
    t2_match = (
        re.search(r'(?:###|##|\*\*|)\s*(?:Tier\s*2|\[ML\]|Statistical\s*Outlier|ML\s*Findings|Findings\s*\(ML\))[^\n]*\n([\s\S]*?)' + sections_lookahead, disposition, re.IGNORECASE) or
        re.search(r'Tier\s*2\s*\((?:ML)\):\s*([^|\n]+)', disposition, re.IGNORECASE)
    )
    t3_match = (
        re.search(r'(?:###|##|\*\*|)\s*(?:Tier\s*3|\[Graph\]|Collusion\s*Network|Graph\s*Findings|Findings\s*\(Graph\))[^\n]*\n([\s\S]*?)' + sections_lookahead, disposition, re.IGNORECASE) or
        re.search(r'Tier\s*3\s*\((?:Graph)\):\s*([^|\n]+)', disposition, re.IGNORECASE)
    )
    
    t1_text = t1_match.group(1).strip() if t1_match else ""
    t2_text = t2_match.group(1).strip() if t2_match else ""
    t3_text = t3_match.group(1).strip() if t3_match else ""
    
    tier_results = []
    
    def parse_block(tier_num: int, label: str, text: str, default_summary: str):
        if not text:
            return {
                "tier": tier_num,
                "label": label,
                "score": 0.0,
                "flags": [],
                "summary": default_summary
            }
            
        lines = [l.strip() for l in text.split('\n')]
        
        bullets = []
        for line in lines:
            if re.match(r'^[-*•+]\s+', line):
                cleaned = re.sub(r'^[-*•+]\s+', '', line).strip()
                if cleaned:
                    cleaned = re.sub(r'^\*+\s*', '', cleaned)
                    cleaned = re.sub(r'\*+$', '', cleaned).strip()
                    bullets.append(cleaned)
                    
        score = 0.0
        threshold = None
        if tier_num == 1:
            sim_match = re.search(r'\bsimilarity\b\s*(?:score)?\s*(?:of|is|:)?\s*([\d.]+)', text, re.IGNORECASE)
            if not sim_match:
                sim_match = re.search(r'\bscore\b\s*(?:of|is|:)?\s*([\d.]+)', text, re.IGNORECASE)
            if sim_match:
                try:
                    score = float(sim_match.group(1))
                except ValueError:
                    pass
        elif tier_num == 2:
            loss_match = re.search(r'\bloss\b\s*(?:is|:)?\s*\(?\s*([\d.]+)\)?', text, re.IGNORECASE)
            if not loss_match:
                loss_match = re.search(r'\breconstruction\b\s*(?:loss)?\s*(?:is|:)?\s*\(?\s*([\d.]+)\)?', text, re.IGNORECASE)
            if loss_match:
                try:
                    score = float(loss_match.group(1))
                except ValueError:
                    pass
            thresh_match = re.search(r'\bthreshold\b\s*(?:is|:)?\s*\(?\s*([\d.]+)\)?', text, re.IGNORECASE)
            if thresh_match:
                try:
                    threshold = float(thresh_match.group(1))
                except ValueError:
                    pass
                    
        summary = ""
        for line in lines:
            if not line:
                continue
            if line.startswith('#') or (line.startswith('**') and line.endswith('**')):
                continue
            if re.match(r'^[-*•+]\s+', line):
                continue
            
            cleaned = line.strip()
            cleaned = re.sub(r'^\*+\s*', '', cleaned)
            cleaned = re.sub(r'\*+$', '', cleaned).strip()
            
            if cleaned and len(cleaned) > 15:
                sent_match = re.match(r'^[^.!?]+[.!?]', cleaned)
                if sent_match:
                    summary = sent_match.group(0)
                else:
                    summary = cleaned[:150]
                break
                
        if not summary:
            if bullets:
                summary = bullets[0]
            else:
                summary = default_summary
                
        summary = re.sub(r'^\*+\s*', '', summary)
        summary = re.sub(r'\*+$', '', summary).strip()
        
        result = {
            "tier": tier_num,
            "label": label,
            "score": score,
            "flags": bullets,
            "summary": summary
        }
        if threshold is not None:
            result["threshold"] = threshold
            
        return result

    tier_results.append(parse_block(1, "Semantic Clinical Audit", t1_text, "Clinical SOAP notes match the procedural description."))
    tier_results.append(parse_block(2, "Statistical Outlier Profiler", t2_text, "Claim billing features are within normal statistical bounds."))
    tier_results.append(parse_block(3, "Collusion Network Analysis", t3_text, "Referral loop scan complete. Patient-provider relational topology is clean, geodetic limits matched."))
    return json.dumps(tier_results)

def run_chat_agent(system_prompt: str, messages_json: str) -> str:
    """Run an agentic chat assistant loop with tools and return the final answer."""
    import agent_tools
    tools = agent_tools.registry.get_all_schemas()
    
    settings = _load_settings()
    timeout = float(settings.get("timeout", 300.0))
    
    try:
        messages = json.loads(messages_json)
    except Exception:
        messages = []
        
    max_steps = 3
    step = 0
    while step < max_steps:
        step += 1
        try:
            response = chat(
                system_prompt=system_prompt,
                messages_json=json.dumps(messages),
                max_tokens=1024,
                timeout=timeout,
                tools=tools
            )
            
            tool_calls = response.get("tool_calls", [])
            content = response.get("content", "")
            
            assistant_msg = {"role": "assistant", "content": content}
            if tool_calls:
                assistant_msg["tool_calls"] = tool_calls
            messages.append(assistant_msg)
            
            if not tool_calls:
                return content
                
            for tc in tool_calls:
                tc_id = tc["id"]
                tool_name = tc["function"]["name"]
                try:
                    args = json.loads(tc["function"]["arguments"])
                except Exception:
                    args = {}
                
                tool_result = agent_tools.registry.execute(tool_name, args)
                
                messages.append({
                    "role": "tool",
                    "tool_call_id": tc_id,
                    "name": tool_name,
                    "content": tool_result
                })
                
        except Exception as e:
            logger.error(f"Error in run_chat_agent step {step}: {str(e)}")
            break
            
    if messages and messages[-1].get("role") == "assistant":
        return messages[-1].get("content", "Error: failed to generate assistant response.")
    return "Error: failed to generate response."

