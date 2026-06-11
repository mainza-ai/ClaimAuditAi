import sys
import os
import json
import pytest
from unittest.mock import patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import agent_graph
from pydantic_graph import End

def test_graph_structure():
    # Verify the graph compiles and all nodes are present in the registry
    assert agent_graph.audit_graph is not None
    node_ids = list(agent_graph.audit_graph.nodes.keys())
    assert "ClaimIngestionNode" in node_ids
    assert "ClinicalAuditNode" in node_ids
    assert "AnomalyAuditNode" in node_ids
    assert "NetworkAuditNode" in node_ids
    assert "LLMSynthesisNode" in node_ids

@pytest.mark.anyio
async def test_nodes_execution_success():
    # Test executing individual nodes with mocked external calls
    state = agent_graph.AuditState(
        patient_id="Patient/1",
        provider_npi="Practitioner/99",
        billed_amount=100.0,
        cpt_codes=["99214"],
        cpt_displays=["Office visit"],
        icd_codes=["I10"],
        code_count=1,
        specialty_code=1.0,
        patient_age=45.0,
        duration_days=1.0
    )

    # Mock NLP audit tool to return a successful check
    mock_nlp_res = {
        "flagged": False,
        "reason": "Clinical notes match.",
        "similarity": 0.85,
        "citations": ["DocumentReference/doc1"]
    }
    
    # Mock Anomaly audit tool
    mock_anomaly_res = {
        "flagged": False,
        "reason": "Claim features are normal.",
        "loss": 0.001,
        "threshold": 0.02
    }

    # Mock Graph audit tool
    mock_graph_res = {
        "flagged": False,
        "reason": "No collusion loops detected.",
        "findings": [],
        "citations": []
    }

    with patch("agent_tools.run_nlp_audit", return_value=json.dumps(mock_nlp_res)), \
         patch("agent_tools.run_anomaly_audit", return_value=json.dumps(mock_anomaly_res)), \
         patch("agent_tools.run_graph_audit", return_value=json.dumps(mock_graph_res)):
         
        # Execute the nodes in sequence
        ingestion = agent_graph.ClaimIngestionNode()
        ctx = agent_graph.GraphRunContext(state=state, deps=None)
        
        node = await ingestion.run(ctx)
        assert isinstance(node, agent_graph.ClinicalAuditNode)
        
        node = await node.run(ctx)
        assert isinstance(node, agent_graph.AnomalyAuditNode)
        assert state.nlp_result["flagged"] is False
        assert "DocumentReference/doc1" in state.nlp_result["citations"]
        
        node = await node.run(ctx)
        assert isinstance(node, agent_graph.NetworkAuditNode)
        assert state.anomaly_result["flagged"] is False
        
        node = await node.run(ctx)
        assert isinstance(node, agent_graph.LLMSynthesisNode)
        assert state.graph_result["flagged"] is False

        # Execute LLM review synthesis
        end_result = await node.run(ctx)
        assert isinstance(end_result, End)
        
        payload = json.loads(end_result.data)
        assert payload["status"] == "APPROVE"
        assert payload["threat_index"] == 0.0
        assert "payment integrity audits completed successfully" in payload["justification"].lower()

@pytest.mark.anyio
async def test_full_graph_run_hold():
    # Test running the entire compiled graph where LLM flags a HOLD
    state = agent_graph.AuditState(
        patient_id="Patient/1",
        provider_npi="Practitioner/99",
        billed_amount=2500.0,
        cpt_codes=["99291"],
        cpt_displays=["Critical care"],
        icd_codes=["I10"],
        code_count=1,
        specialty_code=1.0,
        patient_age=45.0,
        duration_days=1.0
    )

    mock_nlp_res = {"flagged": True, "reason": "No documentation of critical care.", "similarity": 0.1, "citations": []}
    mock_anomaly_res = {"flagged": False, "reason": "Normal features.", "loss": 0.001, "threshold": 0.02}
    mock_graph_res = {"flagged": True, "reason": "Address collision.", "findings": ["Address collision warning"], "citations": ["Practitioner/99"]}

    mock_llm_synthesis_json = {
        "justification": "Held due to missing clinical notes for CPT 99291 and provider address collision.",
        "next_steps": ["Contact provider for medical charts", "Escalate to investigator"]
    }

    with patch("agent_tools.run_nlp_audit", return_value=json.dumps(mock_nlp_res)), \
         patch("agent_tools.run_anomaly_audit", return_value=json.dumps(mock_anomaly_res)), \
         patch("agent_tools.run_graph_audit", return_value=json.dumps(mock_graph_res)), \
         patch("llm_router.chat", return_value=json.dumps(mock_llm_synthesis_json)):
         
        result_json_str = await agent_graph.audit_graph.run(state=state)
        result = json.loads(result_json_str)
        
        assert result["status"] == "HOLD"
        assert result["threat_index"] == 0.65 # T1 (0.35) + T3 (0.30)
        assert "Practitioner/99" in result["citations"]
        assert "Contact provider for medical charts" in result["next_steps"]
        assert "Address collision" in result["findings"]["tier3"]["reason"]
