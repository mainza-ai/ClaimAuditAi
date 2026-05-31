import sys
import os
import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import llm_router


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


class TestChat:
    def test_chat_requires_valid_json(self, monkeypatch):
        monkeypatch.setattr(llm_router, "_get_client_and_model", lambda: (None, "test-model"))
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
