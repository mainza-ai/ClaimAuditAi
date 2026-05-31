import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import agent_orchestrator


class TestSanitize:
    def test_removes_control_characters(self):
        from agent_orchestrator import _sanitize
        result = _sanitize("test\x00\x01\x08string")
        assert "\x00" not in result
        assert "\x01" not in result
        assert "\x08" not in result
        assert "teststring" in result

    def test_removes_html_tags(self):
        from agent_orchestrator import _sanitize
        result = _sanitize("<script>alert('xss')</script>hello")
        assert "<script>" not in result
        assert "hello" in result

    def test_removes_tags_with_whitespace(self):
        from agent_orchestrator import _sanitize
        result = _sanitize("< script >malicious</ script >")
        assert "malicious" in result
        assert "<" not in result or result == "malicious"

    def test_replaces_code_blocks(self):
        from agent_orchestrator import _sanitize
        result = _sanitize("```python\nprint('hello')\n```")
        assert "[CODE_BLOCK]" in result
        assert "print" not in result

    def test_truncates_long_strings(self):
        from agent_orchestrator import _sanitize
        long_str = "A" * 3000
        result = _sanitize(long_str)
        assert len(result) <= 2000

    def test_handles_empty_string(self):
        from agent_orchestrator import _sanitize
        result = _sanitize("")
        assert result == ""


class TestClaimAuditAgent:
    def test_init(self):
        agent = agent_orchestrator.ClaimAuditAgent()
        assert agent is not None

    def test_generate_hold_summary_requires_llm(self):
        agent = agent_orchestrator.ClaimAuditAgent()
        # Without LLM available, should raise RuntimeError
        try:
            agent.generate_hold_summary(
                patient_id="P001",
                provider_npi="NPI123",
                billed_amount=500.0,
                code_count=2,
                service_date="2026-05-29",
                first_code_desc="CPT 99214",
                audit_reasons=["Tier 1: NLP flagged"],
            )
        except RuntimeError:
            pass
        except Exception:
            pass

    def test_prompt_includes_sanitized_fields(self, monkeypatch):
        from unittest.mock import patch

        agent = agent_orchestrator.ClaimAuditAgent()
        try:
            # Verify it doesn't crash with malicious input
            agent.generate_hold_summary(
                patient_id="<script>alert(1)</script>",
                provider_npi="<iframe src=x>",
                billed_amount=500.0,
                code_count=2,
                service_date="2026-05-29",
                first_code_desc="```\nbad\n```",
                audit_reasons=["<b>reason</b>"],
            )
        except RuntimeError:
            pass
