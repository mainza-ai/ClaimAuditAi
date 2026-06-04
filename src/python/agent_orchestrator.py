import sys
import re
from llm_router import generate as llm_generate, clean_non_bmp as clean_non_bmp

try:
    import iris
except ImportError:
    iris = None

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
        safe_patient_id = _sanitize(patient_id)
        safe_provider = _sanitize(provider_npi)
        safe_desc = _sanitize(first_code_desc)
        reasons_str = "\n".join([f"- {_sanitize(r)}" for r in audit_reasons])

        # Coerce types — ObjectScript bridge may pass numbers as strings
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
            return llm_generate(prompt)
        except Exception as e:
            sys.stderr.write(f"LLM Agent Error: {str(e)}\n")
            raise RuntimeError(f"LLM Agent Adjudication Error: {str(e)}")
