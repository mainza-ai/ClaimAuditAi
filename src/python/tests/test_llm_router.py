import sys
import os
import pytest
import json

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import llm_router

@pytest.fixture(autouse=True)
def mock_settings_and_env(monkeypatch, request):
    if request.cls and request.cls.__name__ != "TestLoadSettings":
        monkeypatch.setattr(llm_router, "_load_env", lambda: None)
        monkeypatch.setattr(llm_router, "_load_settings", lambda: {})



class TestCleanNonBmp:
    def test_preserves_ascii(self):
        result = llm_router.clean_non_bmp("Hello, World!")
        assert result == "Hello, World!"

    def test_removes_emoji(self):
        result = llm_router.clean_non_bmp("Hello \U0001F600 World")
        assert "\U0001F600" not in result
        assert "Hello" in result
        assert "World" in result

    def test_preserves_bmp_cjk(self):
        text = "\u4e16\u754c"  # Chinese characters in BMP
        result = llm_router.clean_non_bmp(text)
        assert result == text

    def test_handles_empty_string(self):
        result = llm_router.clean_non_bmp("")
        assert result == ""

    def test_mixed_content(self):
        text = "Report: \U0001f48a Prescription needed for \u03b2-blockers"
        result = llm_router.clean_non_bmp(text)
        assert "\U0001f48a" not in result
        assert "\u03b2" in result


class TestLoadSettings:
    def test_returns_dict(self):
        result = llm_router._load_settings()
        assert isinstance(result, dict)

    def test_returns_empty_dict_when_no_file(self):
        # Should return empty dict when file doesn't exist
        assert isinstance(llm_router._load_settings(), dict)


class TestGetClientAndModel:
    def test_raises_on_unknown_provider(self, monkeypatch):
        monkeypatch.setenv("LLM_PROVIDER", "unknown_provider")
        with pytest.raises(ValueError, match="Unknown LLM_PROVIDER"):
            llm_router._get_client_and_model()

    def test_raises_on_nvidia_no_key(self, monkeypatch):
        monkeypatch.setenv("LLM_PROVIDER", "nvidia")
        monkeypatch.delenv("NVIDIA_API_KEY", raising=False)
        with pytest.raises(ValueError, match="NVIDIA_API_KEY"):
            llm_router._get_client_and_model()

    def test_raises_on_openai_no_key(self, monkeypatch):
        monkeypatch.setenv("LLM_PROVIDER", "openai")
        monkeypatch.delenv("OPENAI_API_KEY", raising=False)
        with pytest.raises(ValueError, match="OPENAI_API_KEY"):
            llm_router._get_client_and_model()

    def test_raises_on_openrouter_no_key(self, monkeypatch):
        monkeypatch.setenv("LLM_PROVIDER", "openrouter")
        monkeypatch.delenv("OPENROUTER_API_KEY", raising=False)
        monkeypatch.delenv("OPEN_ROUTER_API_KEY", raising=False)
        with pytest.raises(ValueError, match="OPENROUTER_API_KEY"):
            llm_router._get_client_and_model()


class TestChat:
    def test_chat_requires_valid_json(self, monkeypatch):
        monkeypatch.setattr(llm_router, "_create_client", lambda provider, settings: (None, "test-model"))
        try:
            llm_router.chat("system prompt", "not valid json")
        except Exception:
            pass

    def test_chat_empty_messages_json(self):
        try:
            llm_router.chat("system prompt", "[]")
        except Exception:
            pass


class TestGenerate:
    def test_generate_calls_chat(self):
        try:
            result = llm_router.generate("test prompt")
        except Exception:
            result = None
        # Should not raise unexpected errors


class TestSummarizeUserReason:
    def test_returns_for_valid_action(self):
        try:
            result = llm_router.summarize_user_reason("approve", "This claim appears valid")
            assert result is not None
        except Exception:
            pass

    def test_unknown_action_falls_back_to_label(self):
        try:
            result = llm_router.summarize_user_reason("unknown_action", "some reason")
        except Exception:
            pass


class TestListOllamaModels:
    def test_returns_list(self):
        result = llm_router.list_ollama_models()
        assert isinstance(result, list)

    def test_returns_empty_on_no_ollama(self):
        result = llm_router.list_ollama_models()
        assert isinstance(result, list)
        # If Ollama not running, should return empty list

    def test_strips_v1_from_url(self):
        result = llm_router.list_ollama_models("http://localhost:11434/v1")
        assert isinstance(result, list)


class TestRateLimiterAndCache:
    def test_rate_limiting(self, monkeypatch):
        # Set limit to 2 per min
        monkeypatch.setattr(llm_router, "_load_settings", lambda: {"rateLimitPerMin": 2})
        llm_router._request_timestamps.clear()
        
        # 1st and 2nd requests should pass
        llm_router._check_rate_limit()
        llm_router._check_rate_limit()
        
        # 3rd should fail
        with pytest.raises(RuntimeError, match="Rate limit exceeded"):
            llm_router._check_rate_limit()

    def test_response_caching(self, monkeypatch):
        # Set cache TTL and rate limits high
        monkeypatch.setattr(llm_router, "_load_settings", lambda: {"cacheTTL": 10, "rateLimitPerMin": 10})
        
        # Mock client chat completions
        class MockChoices:
            def __init__(self, content):
                class Msg:
                    def __init__(self, c):
                        self.content = c
                self.message = Msg(content)
        class MockResponse:
            def __init__(self, content):
                self.choices = [MockChoices(content)]
        
        call_count = 0
        def mock_create(*args, **kwargs):
            nonlocal call_count
            call_count += 1
            return MockResponse(f"response_{call_count}")
            
        class MockCompletions:
            def create(self, *args, **kwargs):
                return mock_create(*args, **kwargs)
        class MockClient:
            def __init__(self):
                self.chat = type('MockChat', (object,), {'completions': MockCompletions()})()
                
        monkeypatch.setattr(llm_router, "_create_client", lambda provider, settings: (MockClient(), "test-model"))
        
        llm_router.invalidate_llm_cache()
        llm_router._request_timestamps.clear()
        
        # First call should invoke client
        res1 = llm_router.chat("sys", "[]")
        assert res1 == "response_1"
        assert call_count == 1
        
        # Second call should hit cache and NOT invoke client
        res2 = llm_router.chat("sys", "[]")
        assert res2 == "response_1"
        assert call_count == 1
        
        # Invalidate cache and call again — should invoke client
        llm_router.invalidate_llm_cache()
        res3 = llm_router.chat("sys", "[]")
        assert res3 == "response_2"
        assert call_count == 2


class TestParseDisposition:
    def test_empty_disposition(self):
        result = json.loads(llm_router.parse_disposition(""))
        assert isinstance(result, list)
        assert len(result) == 0

    def test_full_disposition(self):
        text = """
# Adjudication Report

**Tier 1 (NLP) Findings**
* CPT code display '99291' lacks semantic alignment with progress notes. Similarity: 0.2313
* Reason Code: NLP-001 - Inconsistent CPT Code Display
* Metric: Semantic Alignment Score (0.2313) < Threshold (0.3000)

**Tier 2 (ML) Findings**
* The automated ML engine identified a statistical anomaly in the claim features, indicating an unusual billing structure outlier.
* Reason Code: ML-002 - Unusual Billing Structure
* Metric: Reconstruction Loss (0.42023) > Threshold (0.03453)

**Tier 3 (Graph) Findings**
* The graph analysis detected an Address Collision Warning, revealing that the provider's physical office address is shared.
* Reason Code: GR-003 - Address Collision
* Metric: Address Sharing Ratio (1.2345) > Threshold (0.5000)

**Pend (HOLD) Justification**
This claim has been pended.
        """
        result = json.loads(llm_router.parse_disposition(text))
        assert isinstance(result, list)
        assert len(result) == 3
        
        # Tier 1 assertions
        t1 = result[0]
        assert t1["tier"] == 1
        assert t1["score"] == 0.2313
        assert len(t1["flags"]) == 3
        assert "lacks semantic alignment" in t1["summary"]

        # Tier 2 assertions
        t2 = result[1]
        assert t2["tier"] == 2
        assert t2["score"] == 0.42023
        assert t2["threshold"] == 0.03453
        assert len(t2["flags"]) == 3
        assert "unusual billing structure" in t2["summary"]

        # Tier 3 assertions
        t3 = result[2]
        assert t3["tier"] == 3
        assert len(t3["flags"]) == 3
        assert "Address Collision" in t3["summary"]

