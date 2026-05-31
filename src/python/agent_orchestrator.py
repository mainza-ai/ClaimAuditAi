import sys
from llm_router import generate as llm_generate, clean_non_bmp as clean_non_bmp

try:
    import iris
except ImportError:
    iris = None

class ClaimAuditAgent:
    def __init__(self):
        pass

    def generate_hold_summary(self, patient_id: str, provider_npi: str, billed_amount: float,
                              code_count: int, service_date: str, first_code_desc: str,
                              audit_reasons: list) -> str:
        reasons_str = "\n".join([f"- {r}" for r in audit_reasons])

        prompt = f"""You are an advanced autonomous Payment Integrity Officer at a major health insurance payer.
Your primary task is to review clinical-financial audits and construct a comprehensive, explainable adjudication summary for claims that have been flagged as high-risk (HOLD) by our automated engines.

Adjudication Target Claim Details:
- Patient ID: {patient_id}
- Submitting Provider NPI: {provider_npi}
- Billed CPT Code: {first_code_desc}
- Total Billed Amount: ${billed_amount:.2f}
- Number of Line Items: {code_count}
- Service Date: {service_date}

Automated Audit Findings:
{reasons_str}

Please generate a professional, detailed, and highly explainable adjudication report.
1. Outline the exact reason codes and metrics.
2. Formally justify why the claim is being pended ("HOLD").
3. Provide structured, actionable next steps for the clinical audit queue.

CRITICAL: Do NOT use any emojis or characters outside the Basic Multilingual Plane (characters must fit within the standard regex [\u0020-\uFFFF]) in your output.
"""
        try:
            return llm_generate(prompt)
        except Exception as e:
            sys.stderr.write(f"LLM Agent Error: {str(e)}\n")
            raise RuntimeError(f"LLM Agent Adjudication Error: {str(e)}")
