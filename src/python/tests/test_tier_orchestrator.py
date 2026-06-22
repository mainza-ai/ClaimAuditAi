import time
import pytest
from unittest.mock import patch, MagicMock
import tier_orchestrator

def setup_function():
    # Reset circuit breaker state before each test
    with tier_orchestrator._circuit_lock:
        tier_orchestrator._circuit_state.clear()

def test_circuit_breaker_flow():
    tier_num = 1
    # Mocking nlp_auditor function import failure to trigger circuit breaker
    with patch("builtins.__import__", side_effect=ImportError("Mock import error")):
        # Failures 1, 2, 3
        res1 = tier_orchestrator._run_tier(tier_num, ("P1", ["CPT1"]), {})
        assert "engine failure" in res1["reason"]
        assert res1["flagged"] is True
        
        res2 = tier_orchestrator._run_tier(tier_num, ("P1", ["CPT1"]), {})
        assert "engine failure" in res2["reason"]
        
        res3 = tier_orchestrator._run_tier(tier_num, ("P1", ["CPT1"]), {})
        assert "engine failure" in res3["reason"]
        
        # Next call should hit circuit breaker open
        res4 = tier_orchestrator._run_tier(tier_num, ("P1", ["CPT1"]), {})
        assert "circuit breaker open" in res4["reason"]
        assert res4["flagged"] is True
        
        status = tier_orchestrator.get_circuit_status()
        assert status["nlp"]["is_open"] is True
        assert status["nlp"]["failures"] == 3

def test_circuit_breaker_reset():
    tier_num = 1
    # Trigger open circuit
    with patch("builtins.__import__", side_effect=ImportError("Mock import error")):
        for _ in range(3):
            tier_orchestrator._run_tier(tier_num, ("P1", ["CPT1"]), {})
            
    # Modify open_until time to mock cooldown expiration
    with tier_orchestrator._circuit_lock:
        tier_orchestrator._circuit_state[tier_num]["open_until"] = time.time() - 10
        
    # Mock success path
    mock_module = MagicMock()
    mock_module.verify_clinical_validity = MagicMock(return_value={"flagged": False, "reason": "Aligned"})
    
    with patch("builtins.__import__", return_value=mock_module):
        res = tier_orchestrator._run_tier(tier_num, ("P1", ["CPT1"]), {})
        assert res["flagged"] is False
        assert res["reason"] == "Aligned"
        
        # Verify circuit status is reset
        status = tier_orchestrator.get_circuit_status()
        assert status["nlp"]["is_open"] is False
        assert status["nlp"]["failures"] == 0

@patch("dx_procedure_validator.validate_diagnosis_procedure")
@patch("nlp_auditor.verify_clinical_validity")
@patch("autoencoder_train.evaluate_claim_anomaly")
@patch("graph_analyzer.check_collusion_network")
def test_run_all_tiers_success(mock_graph, mock_autoencoder, mock_nlp, mock_dx_val):
    # Mock success responses
    mock_nlp.return_value = {"flagged": False, "reason": "NLP OK", "similarity": 0.95, "citations": ["Doc1"]}
    mock_dx_val.return_value = {"flagged": False, "reason": "Edit OK"}
    mock_autoencoder.return_value = {"flagged": False, "reason": "Anomaly OK", "loss": 0.005, "threshold": 0.02}
    mock_graph.return_value = {"flagged": False, "findings": [], "citations": ["Claim1"]}
    
    results = tier_orchestrator.run_all_tiers(
        patient_id="P1",
        provider_npi="NPI1",
        cpt_codes=["99213"],
        cpt_displays=["Office Visit"],
        icd_codes=["I10"],
        billed_amount=150.00,
        code_count=1,
        specialty_code=2.0,
        patient_age=30.0,
        duration_days=1.0,
        service_date="2026-06-01",
        claim_id="C1"
    )
    
    assert results["tier1"]["flagged"] is False
    assert results["tier2"]["flagged"] is False
    assert results["tier3"]["flagged"] is False
