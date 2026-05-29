import os
import sys
from openai import OpenAI

# Try to import iris
try:
    import iris
except ImportError:
    iris = None

def clean_non_bmp(text: str) -> str:
    """Removes emojis and other characters outside the Basic Multilingual Plane (BMP)
    to satisfy strict FHIR schema validations in IRIS."""
    return "".join(c for c in text if ord(c) <= 0xFFFF)

class ClaimAuditAgent:
    def __init__(self):
        # Retrieve LLM Provider configuration from environment variables
        self.provider = os.getenv("LLM_PROVIDER", "nvidia").lower()
        
        if self.provider == "nvidia":
            api_key = os.getenv("NVIDIA_API_KEY", "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")
            base_url = os.getenv("NVIDIA_BASE_URL", "https://integrate.api.nvidia.com/v1")
            self.model = os.getenv("NVIDIA_MODEL", "z-ai/glm-5.1")
            self.client = OpenAI(base_url=base_url, api_key=api_key)
            
        elif self.provider == "ollama":
            api_key = "ollama"
            base_url = os.getenv("OLLAMA_BASE_URL", "http://host.docker.internal:11434/v1")
            self.model = os.getenv("OLLAMA_MODEL", "llama3")
            self.client = OpenAI(base_url=base_url, api_key=api_key)
            
        else:
            # Standard OpenAI
            api_key = os.getenv("OPENAI_API_KEY", "")
            base_url = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1")
            self.model = os.getenv("OPENAI_MODEL", "gpt-4")
            self.client = OpenAI(base_url=base_url, api_key=api_key)

    def generate_hold_summary(self, patient_id: str, provider_npi: str, billed_amount: float, 
                              code_count: int, service_date: str, first_code_desc: str, 
                              audit_reasons: list) -> str:
        """Authors an explainable markdown hold adjudication report utilizing the configured LLM provider."""
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
            completion = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": "You are a professional payment integrity adjudication officer. Format your response in markdown. Do not include any emojis in your response."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.7,
                max_tokens=1024,
                timeout=8.0
            )
            return clean_non_bmp(completion.choices[0].message.content)
        except Exception as e:
            sys.stderr.write(f"LLM Agent Error: {str(e)}\n")
            # Fallback explanation if LLM fails (emojis strictly replaced by ASCII markers)
            fallback = f"""# [WARNING] Payment Integrity Adjudication HOLD Notification
This claim has been pended for manual review due to high threat index anomaly scores.

### [NLP] Flagged Discrepancy Summaries:
{reasons_str}

### [Adjudication] Adjudication Actions:
- **Transaction Status**: HOLD (Queued for Audit)
- **Assigned Queue**: Clinical Audit Review
- **Next Steps**: Provider must submit comprehensive medical charts and physical progress logs to substantiate the billed procedural severity."""
            return clean_non_bmp(fallback)
