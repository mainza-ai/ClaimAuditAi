import sys
import os
import json
from unittest.mock import patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import agent_orchestrator
import llm_router

def test_react_loop_success():
    agent = agent_orchestrator.ClaimAuditAgent()

    # We test the graph's workflow:
    # Under a clean audit (billed amount $120), Tiers return non-flagged results.
    # The graph completes with APPROVE status without requiring any LLM synthesis calls.
    call_count = 0

    def mock_chat(*args, **kwargs):
        nonlocal call_count
        call_count += 1
        return "{}"

    # Mock all three tier tools to be clean
    mock_nlp_res = {"flagged": False, "reason": "Match", "similarity": 0.9, "citations": []}
    mock_anomaly_res = {"flagged": False, "reason": "Normal", "loss": 0.001, "threshold": 0.02}
    mock_graph_res = {"flagged": False, "reason": "Clean", "findings": [], "citations": []}

    with patch("llm_router.chat", side_effect=mock_chat), \
         patch("agent_tools.run_nlp_audit", return_value=json.dumps(mock_nlp_res)), \
         patch("agent_tools.run_anomaly_audit", return_value=json.dumps(mock_anomaly_res)), \
         patch("agent_tools.run_graph_audit", return_value=json.dumps(mock_graph_res)):
         
        result_json_str = agent.audit_claim_agent(
            patient_id="Patient/1",
            provider_npi="Practitioner/99",
            cpt_codes=["99214"],
            cpt_displays=["Office visit"],
            icd_codes=["I10"],
            billed_amount=120.0,
            code_count=1,
            specialty_code=1.0,
            patient_age=45.0,
            duration_days=1.0,
            service_date="2026-06-11",
            claim_id="claim-abc"
        )
        
        # Verify no LLM calls were made since claim is clean (APPROVE)
        assert call_count == 0
        
        # Verify final JSON content
        result = json.loads(result_json_str)
        assert result["status"] == "APPROVE"
        assert result["threat_index"] == 0.0
        assert result["findings"]["tier1"]["flagged"] is False


def test_react_loop_fallback_on_llm_failure():
    agent = agent_orchestrator.ClaimAuditAgent()

    # Mock agent_graph.execute_graph_audit to raise an exception, forcing fallback to deterministic run_all_tiers
    async def mock_execute_graph_fail(*args, **kwargs):
        raise RuntimeError("Graph FSM offline")

    # Mock tier_orchestrator.run_all_tiers to return typical results
    mock_tiers_result = {
        "tier1": {"flagged": False, "reason": "Check passed", "similarity": 0.95, "citations": ["DocumentReference/1"]},
        "tier2": {"flagged": False, "reason": "Statistical check passed", "loss": 0.005, "threshold": 0.02},
        "tier3": {"flagged": False, "reason": "Collusion check passed", "findings": [], "citations": []}
    }

    with patch("agent_graph.execute_graph_audit", side_effect=mock_execute_graph_fail), \
         patch("tier_orchestrator.run_all_tiers", return_value=mock_tiers_result):
         
        result_json_str = agent.audit_claim_agent(
            patient_id="Patient/1",
            provider_npi="Practitioner/99",
            cpt_codes=["99214"],
            cpt_displays=["Office visit"],
            icd_codes=["I10"],
            billed_amount=120.0,
            code_count=1,
            specialty_code=1.0,
            patient_age=45.0,
            duration_days=1.0,
            service_date="2026-06-11",
            claim_id="claim-abc"
        )
        
        # Parse fallback JSON
        result = json.loads(result_json_str)
        assert result["status"] == "APPROVE"
        assert result["threat_index"] == 0.0
        assert "Deterministic audit fallback completed" in result["justification"]
        assert "DocumentReference/1" in result["findings"]["tier1"]["citations"]
