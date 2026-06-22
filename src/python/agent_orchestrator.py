import sys
import re
import json
import logging
from typing import Dict, Any, List

import llm_router
import agent_tools
import tier_orchestrator

logger = logging.getLogger(__name__)

def _sanitize(value: str) -> str:
    if not isinstance(value, str):
        return str(value)
    value = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', '', value)
    value = re.sub(r'</?\s*[a-zA-Z]+\s*>', '', value)
    value = re.sub(r'```[a-zA-Z]*\s*\n[\s\S]*?\n```', '[CODE_BLOCK]', value)
    return value.strip()[:2000]

class ClaimAuditAgent:
    def __init__(self):
        pass

    def generate_hold_summary(self, patient_id: str, provider_npi: str, billed_amount: float,
                               code_count: int, service_date: str, first_code_desc: str,
                               audit_reasons: list) -> str:
        """Original summary generation for backward compatibility, enhanced with LLM sanitization."""
        safe_patient_id = _sanitize(patient_id)
        safe_provider = _sanitize(provider_npi)
        safe_desc = _sanitize(first_code_desc)
        reasons_str = "\n".join([f"- {_sanitize(r)}" for r in audit_reasons])

        try:
            billed_amount = float(billed_amount)
        except (ValueError, TypeError):
            billed_amount = 0.0
        try:
            code_count = int(code_count)
        except (ValueError, TypeError):
            code_count = 0

        prompt = f"""You are an advanced autonomous Payment Integrity Officer at a major health insurance payer.
Your primary task is to review clinical-financial audits and construct a comprehensive, explainable adjudication summary for claims that have been flagged as high-risk (HOLD) by our automated engines.

Adjudication Target Claim Details:
- Patient ID: {safe_patient_id}
- Submitting Provider NPI: {safe_provider}
- Billed CPT Code: {safe_desc}
- Total Billed Amount: ${billed_amount:.2f}
- Number of Line Items: {code_count}
- Service Date: {service_date}

Automated Audit Findings:
{reasons_str}

Please generate a professional, detailed, and highly explainable adjudication report.
1. Outline the exact reason codes and metrics.
2. Formally justify why the claim is being pended ("HOLD").
3. Provide structured, actionable next steps for the clinical audit queue.

CRITICAL: Do NOT use any emojis or characters outside the Basic Multilingual Plane (characters must fit within the standard regex [\\u0020-\\uFFFF]) in your output.
"""
        try:
            return llm_router.generate(prompt)
        except Exception as e:
            sys.stderr.write(f"LLM Agent Error: {str(e)}\n")
            raise RuntimeError(f"LLM Agent Adjudication Error: {str(e)}")

    def _run_deterministic_fallback(self, patient_id: str, provider_npi: str, cpt_codes: list, cpt_displays: list, icd_codes: list,
                                    billed_amount: float, code_count: int, specialty_code: float, patient_age: float, duration_days: float,
                                    service_date: str = None, claim_id: str = None) -> str:
        """Helper to run deterministic all-tiers check directly and return equivalent structured JSON."""
        logger.info("Executing deterministic fallback audit pipeline.")
        try:
            deterministic_results = tier_orchestrator.run_all_tiers(
                patient_id=patient_id,
                provider_npi=provider_npi,
                cpt_codes=cpt_codes,
                cpt_displays=cpt_displays,
                icd_codes=icd_codes,
                billed_amount=billed_amount,
                code_count=code_count,
                specialty_code=specialty_code,
                patient_age=patient_age,
                duration_days=duration_days,
                service_date=service_date,
                claim_id=claim_id
            )
            
            # Combine scores to build equivalent structured JSON
            t1 = deterministic_results.get("tier1", {"flagged": False, "reason": "", "similarity": 1.0, "citations": []})
            t2 = deterministic_results.get("tier2", {"flagged": False, "reason": "", "loss": 0.0, "threshold": 0.02, "citations": []})
            t3 = deterministic_results.get("tier3", {"flagged": False, "reason": "", "findings": [], "citations": []})
            
            score = 0.0
            reasons = []
            citations = []
            
            if t1.get("flagged"):
                score += 0.35
                reasons.append(f"Tier 1 (NLP): {t1.get('reason')}")
                citations.extend(t1.get("citations", []))
            if t2.get("flagged"):
                score += 0.35
                reasons.append(f"Tier 2 (ML): {t2.get('reason')}")
                citations.extend(t2.get("citations", []))
            if t3.get("flagged"):
                score += 0.30
                reasons.append(f"Tier 3 (Graph): {t3.get('reason')}")
                citations.extend(t3.get("citations", []))
                
            if score > 1.0:
                score = 1.0
                
            status = "HOLD" if score >= 0.35 else "APPROVE"
            
            fallback_payload = {
                "status": status,
                "threat_index": score,
                "findings": {
                    "tier1": {
                        "flagged": t1.get("flagged", False),
                        "reason": t1.get("reason", ""),
                        "similarity": t1.get("similarity", 1.0),
                        "citations": t1.get("citations", [])
                    },
                    "tier2": {
                        "flagged": t2.get("flagged", False),
                        "reason": t2.get("reason", ""),
                        "loss": t2.get("loss", 0.0),
                        "threshold": t2.get("threshold", 0.02),
                        "citations": t2.get("citations", [])
                    },
                    "tier3": {
                        "flagged": t3.get("flagged", False),
                        "reason": t3.get("reason", ""),
                        "findings": t3.get("findings", []),
                        "citations": t3.get("citations", [])
                    }
                },
                "citations": list(set(citations)),
                "justification": f"Deterministic audit fallback completed. Threat score {score:.2f}.",
                "next_steps": ["Review flagged anomalies manually"] if status == "HOLD" else []
            }
            return json.dumps(fallback_payload)
            
        except Exception as e:
            logger.critical(f"Critical error in deterministic fallback pipeline: {str(e)}")
            # Safe default error response
            error_payload = {
                "status": "HOLD",
                "threat_index": 1.0,
                "findings": {
                    "tier1": {"flagged": True, "reason": f"Audit crash: {str(e)}", "similarity": 0.0, "citations": []},
                    "tier2": {"flagged": True, "reason": "Audit failed to execute", "loss": 1.0, "threshold": 0.02, "citations": []},
                    "tier3": {"flagged": True, "reason": "Audit failed to execute", "findings": [], "citations": []}
                },
                "citations": [],
                "justification": f"Claim placed on hold due to system crash: {str(e)}",
                "next_steps": ["Contact system administrator", "Perform manual claim audit review"]
            }
            return json.dumps(error_payload)

    def audit_claim_agent(self, patient_id: str, provider_npi: str, cpt_codes: list, cpt_displays: list, icd_codes: list,
                          billed_amount: float, code_count: int, specialty_code: float, patient_age: float, duration_days: float,
                          service_date: str = None, claim_id: str = None, force_deterministic: bool = False) -> str:
        """Run the compiled Pydantic Graph FSM to audit the claim and return a structured JSON response."""
        
        # If force_deterministic is set (e.g. during bulk database seeding), bypass the LLM loop entirely
        if force_deterministic or str(force_deterministic) == "1" or str(force_deterministic).lower() == "true":
            return self._run_deterministic_fallback(
                patient_id=patient_id,
                provider_npi=provider_npi,
                cpt_codes=cpt_codes,
                cpt_displays=cpt_displays,
                icd_codes=icd_codes,
                billed_amount=billed_amount,
                code_count=code_count,
                specialty_code=specialty_code,
                patient_age=patient_age,
                duration_days=duration_days,
                service_date=service_date,
                claim_id=claim_id
            )

        import asyncio
        import agent_graph
        try:
            result = asyncio.run(
                agent_graph.execute_graph_audit(
                    patient_id=patient_id,
                    provider_npi=provider_npi,
                    cpt_codes=cpt_codes,
                    cpt_displays=cpt_displays,
                    icd_codes=icd_codes,
                    billed_amount=billed_amount,
                    code_count=code_count,
                    specialty_code=specialty_code,
                    patient_age=patient_age,
                    duration_days=duration_days,
                    service_date=service_date,
                    claim_id=claim_id
                )
            )
            return result
        except Exception as e:
            logger.error(f"Pydantic Graph FSM failed: {str(e)}. Running deterministic fallback.")
            return self._run_deterministic_fallback(
                patient_id=patient_id,
                provider_npi=provider_npi,
                cpt_codes=cpt_codes,
                cpt_displays=cpt_displays,
                icd_codes=icd_codes,
                billed_amount=billed_amount,
                code_count=code_count,
                specialty_code=specialty_code,
                patient_age=patient_age,
                duration_days=duration_days,
                service_date=service_date,
                claim_id=claim_id
            )

