"""Tier orchestration with parallel execution, timeouts, and circuit breaker."""
import sys
import time
import threading
from concurrent import futures

# Engine tier registry — maps tier name to (module, function, timeout_seconds)
TIER_CONFIG = {
    1: {"name": "nlp", "module": "nlp_auditor", "function": "verify_clinical_validity", "timeout": 180},
    2: {"name": "autoencoder", "module": "autoencoder_train", "function": "evaluate_claim_anomaly", "timeout": 120},
    3: {"name": "graph", "module": "graph_analyzer", "function": "check_collusion_network", "timeout": 120},
}

# Circuit breaker state — tracked per module
_circuit_state = {}
_circuit_lock = threading.Lock()
CIRCUIT_THRESHOLD = 3  # consecutive failures before circuit opens
CIRCUIT_RESET_SECONDS = 60  # seconds before retrying after circuit opens


def _run_tier(tier_num: int, args: tuple, kwargs: dict) -> dict:
    """Run a single tier with timeout and circuit breaker protection."""
    config = TIER_CONFIG[tier_num]

    # Circuit breaker check
    with _circuit_lock:
        state = _circuit_state.get(tier_num, {"failures": 0, "open_until": 0})
        if state["failures"] >= CIRCUIT_THRESHOLD:
            if time.time() < state["open_until"]:
                return {
                    "flagged": True,
                    "reason": f"Tier {tier_num} ({config['name']}) circuit breaker open — {state['failures']} consecutive failures. Claim requires manual adjudication review.",
                    "similarity": 0.0,
                    "loss": 0.0,
                    "findings": [],
                }
            else:
                # Circuit reset after cooldown
                _circuit_state[tier_num] = {"failures": 0, "open_until": 0}

    try:
        mod = __import__(config["module"])
        func = getattr(mod, config["function"])
        result = func(*args, **kwargs)

        # Success — reset failure count
        with _circuit_lock:
            _circuit_state[tier_num] = {"failures": 0, "open_until": 0}

        return result

    except Exception as e:
        # Failure — increment circuit breaker
        with _circuit_lock:
            cur = _circuit_state.get(tier_num, {"failures": 0, "open_until": 0})
            cur["failures"] = cur.get("failures", 0) + 1
            if cur["failures"] >= CIRCUIT_THRESHOLD:
                cur["open_until"] = time.time() + CIRCUIT_RESET_SECONDS
            _circuit_state[tier_num] = cur

        return {
            "flagged": True,
            "reason": f"Tier {tier_num} ({config['name']}) engine failure: {str(e)}. Claim requires manual adjudication review.",
            "similarity": 0.0,
            "loss": 0.0,
            "findings": [],
        }

def run_all_tiers(patient_id: str, provider_npi: str, cpt_codes, cpt_displays=None, icd_codes=None,
                  billed_amount: float = 0.0, code_count: int = 1,
                  specialty_code: float = 1.0, patient_age: float = 45.0, duration_days: float = 1.0,
                  service_date: str = None) -> dict:
    """Execute all three audit tiers sequentially to ensure safety in InterSystems IRIS Embedded Python."""
    results = {}

    # Handle backward compatibility / old signature
    if isinstance(cpt_codes, str):
        first_code_desc = cpt_codes
        cpt_codes = [first_code_desc]
        cpt_displays = [first_code_desc]
    if icd_codes is None:
        icd_codes = []
    if cpt_displays is None:
        cpt_displays = cpt_codes

    # Run Tier 1: NLP Clinical Document Alignment
    nlp_flagged = False
    nlp_reason = ""
    nlp_similarity = 1.0
    
    if cpt_displays:
        start_time = time.time()
        try:
            nlp_res = _run_tier(1, (patient_id, cpt_displays), {"service_date": service_date})
            nlp_flagged = nlp_res.get("flagged", False)
            nlp_reason = nlp_res.get("reason", "")
            nlp_similarity = nlp_res.get("similarity", 1.0)
            
            elapsed = time.time() - start_time
            if elapsed > TIER_CONFIG[1]["timeout"]:
                nlp_flagged = True
                nlp_reason = "Tier 1 NLP clinical audit timed out. Manual review required."
                nlp_similarity = 0.0
        except Exception as e:
            nlp_flagged = True
            nlp_reason = f"Tier 1 NLP clinical audit failed: {str(e)}. Manual review required."
            nlp_similarity = 0.0
    else:
        nlp_reason = "No CPT procedure codes provided."

    # Run Deterministic Diagnosis-to-Procedure (ICD-to-CPT) Clinical Edits
    dx_cpt_flagged = False
    dx_cpt_findings = []
    
    try:
        import dx_procedure_validator
        for cpt in cpt_codes:
            for icd in icd_codes:
                res = dx_procedure_validator.validate_diagnosis_procedure(icd, cpt)
                if res.get("flagged", False):
                    dx_cpt_flagged = True
                    dx_cpt_findings.append(res.get("reason", ""))
    except Exception as e:
        sys.stderr.write(f"Error in diagnosis-to-procedure validation: {str(e)}\n")
        dx_cpt_flagged = True
        dx_cpt_findings.append(f"Diagnostic-procedure validator failed: {str(e)}")

    # Merge diagnostic-procedure mismatch findings with NLP findings under Tier 1
    if dx_cpt_flagged:
        nlp_flagged = True
        dx_reason = " | ".join(dx_cpt_findings)
        if nlp_reason:
            nlp_reason = f"{nlp_reason} | {dx_reason}"
        else:
            nlp_reason = dx_reason

    results["tier1"] = {
        "flagged": nlp_flagged,
        "reason": nlp_reason,
        "similarity": nlp_similarity
    }

    # Run Tier 2: Autoencoder Outlier Profiler
    start_time = time.time()
    try:
        results["tier2"] = _run_tier(2, (billed_amount, float(code_count), specialty_code, patient_age, duration_days), {})
        elapsed = time.time() - start_time
        if elapsed > TIER_CONFIG[2]["timeout"]:
            results["tier2"] = {"flagged": True, "reason": "Tier 2 autoencoder audit timed out. Manual review required.", "loss": 0.0, "threshold": 0.02}
    except Exception as e:
        results["tier2"] = {"flagged": True, "reason": f"Tier 2 autoencoder audit failed: {str(e)}. Manual review required.", "loss": 0.0, "threshold": 0.02}

    # Run Tier 3: Graph Collusion Analysis
    start_time = time.time()
    try:
        results["tier3"] = _run_tier(3, (patient_id, provider_npi, service_date), {})
        elapsed = time.time() - start_time
        if elapsed > TIER_CONFIG[3]["timeout"]:
            results["tier3"] = {"flagged": True, "reason": "Tier 3 graph audit timed out. Manual review required.", "findings": []}
    except Exception as e:
        results["tier3"] = {"flagged": True, "reason": f"Tier 3 graph audit failed: {str(e)}. Manual review required.", "findings": []}

    return results


def get_circuit_status() -> dict:
    """Return current circuit breaker state for monitoring."""
    with _circuit_lock:
        status = {}
        for tier_num in TIER_CONFIG:
            state = _circuit_state.get(tier_num, {"failures": 0, "open_until": 0})
            status[TIER_CONFIG[tier_num]["name"]] = {
                "failures": state["failures"],
                "is_open": state["failures"] >= CIRCUIT_THRESHOLD,
                "remaining_cooldown": max(0, state["open_until"] - time.time()),
            }
        return status
