from __future__ import annotations
import sys
import json
import logging
import time
from dataclasses import dataclass
from typing import List, Dict, Any, Optional
from pydantic import BaseModel, Field
from pydantic_graph import BaseNode, End, GraphBuilder, GraphRunContext, StepContext

import agent_tools
import llm_router

logger = logging.getLogger(__name__)

# 1. Define the Shared State
class AuditState(BaseModel):
    claim_id: Optional[str] = None
    patient_id: str
    provider_npi: str
    billed_amount: float
    cpt_codes: List[str] = Field(default_factory=list)
    cpt_displays: List[str] = Field(default_factory=list)
    icd_codes: List[str] = Field(default_factory=list)
    code_count: int = 1
    specialty_code: float = 1.0
    patient_age: float = 45.0
    duration_days: float = 1.0
    service_date: Optional[str] = None
    force_deterministic: bool = False

    # Accumulated results from graph nodes
    nlp_result: Optional[Dict[str, Any]] = None
    anomaly_result: Optional[Dict[str, Any]] = None
    graph_result: Optional[Dict[str, Any]] = None

    # Final Adjudication Outputs
    status: str = "APPROVE"
    threat_index: float = 0.0
    citations: List[str] = Field(default_factory=list)
    justification: str = ""
    next_steps: List[str] = Field(default_factory=list)


# 2. Define Node Classes
@dataclass
class ClaimIngestionNode(BaseNode[AuditState, None, str]):
    async def run(self, ctx: GraphRunContext[AuditState, None]) -> ClinicalAuditNode:
        logger.info(f"[Graph] Ingesting claim context for patient: {ctx.state.patient_id}")
        return ClinicalAuditNode()


@dataclass
class ClinicalAuditNode(BaseNode[AuditState, None, str]):
    async def run(self, ctx: GraphRunContext[AuditState, None]) -> AnomalyAuditNode:
        logger.info("[Graph] Executing Tier 1: Clinical Audit Node")
        
        nlp_flagged = False
        nlp_reason = ""
        nlp_similarity = 1.0
        nlp_citations = []

        # NLP vector notes check
        if ctx.state.cpt_displays:
            try:
                # Call registered tool
                res_str = agent_tools.run_nlp_audit(ctx.state.patient_id, ctx.state.cpt_displays, ctx.state.service_date)
                res = json.loads(res_str)
                nlp_flagged = res.get("flagged", False)
                nlp_reason = res.get("reason", "")
                nlp_similarity = res.get("similarity", 1.0)
                nlp_citations = res.get("citations", [])
            except Exception as e:
                logger.error(f"NLP tool execution failed: {str(e)}")
                nlp_flagged = True
                nlp_reason = f"Clinical Note Vector search failed: {str(e)}"
                nlp_similarity = 0.0
        else:
            nlp_reason = "No CPT procedure code displays provided."

        # ICD-CPT edits check
        dx_cpt_flagged = False
        dx_cpt_findings = []
        try:
            import dx_procedure_validator
            for cpt in ctx.state.cpt_codes:
                for icd in ctx.state.icd_codes:
                    res = dx_procedure_validator.validate_diagnosis_procedure(icd, cpt)
                    if res.get("flagged", False):
                        dx_cpt_flagged = True
                        dx_cpt_findings.append(res.get("reason", ""))
        except Exception as e:
            logger.error(f"ICD-CPT validation failed: {str(e)}")
            dx_cpt_flagged = True
            dx_cpt_findings.append(f"Diagnostic-procedure validator failed: {str(e)}")

        if dx_cpt_flagged:
            nlp_flagged = True
            dx_reason = " | ".join(dx_cpt_findings)
            if nlp_reason:
                nlp_reason = f"{nlp_reason} | {dx_reason}"
            else:
                nlp_reason = dx_reason
            if ctx.state.claim_id:
                nlp_citations.append(f"Claim/{ctx.state.claim_id}")

        ctx.state.nlp_result = {
            "flagged": nlp_flagged,
            "reason": nlp_reason,
            "similarity": nlp_similarity,
            "citations": list(set(nlp_citations))
        }

        return AnomalyAuditNode()


@dataclass
class AnomalyAuditNode(BaseNode[AuditState, None, str]):
    async def run(self, ctx: GraphRunContext[AuditState, None]) -> NetworkAuditNode:
        logger.info("[Graph] Executing Tier 2: Anomaly Outlier Node")
        
        try:
            res_str = agent_tools.run_anomaly_audit(
                ctx.state.billed_amount,
                float(ctx.state.code_count),
                ctx.state.specialty_code,
                ctx.state.patient_age,
                ctx.state.duration_days
            )
            res = json.loads(res_str)
        except Exception as e:
            logger.error(f"Anomaly tool execution failed: {str(e)}")
            res = {
                "flagged": True,
                "reason": f"Anomaly autoencoder scoring failed: {str(e)}",
                "loss": 0.0,
                "threshold": 0.02
            }

        # Add citations for Tier 2
        t2_citations = []
        if ctx.state.claim_id:
            t2_citations.append(f"Claim/{ctx.state.claim_id}")
        res["citations"] = t2_citations

        ctx.state.anomaly_result = res
        return NetworkAuditNode()


@dataclass
class NetworkAuditNode(BaseNode[AuditState, None, str]):
    async def run(self, ctx: GraphRunContext[AuditState, None]) -> LLMSynthesisNode:
        logger.info("[Graph] Executing Tier 3: Network Collusion Node")
        
        try:
            res_str = agent_tools.run_graph_audit(
                ctx.state.patient_id,
                ctx.state.provider_npi,
                ctx.state.service_date
            )
            res = json.loads(res_str)
        except Exception as e:
            logger.error(f"Graph tool execution failed: {str(e)}")
            res = {
                "flagged": True,
                "reason": f"Collusion graph cycle check failed: {str(e)}",
                "findings": [],
                "citations": []
            }

        if "citations" not in res:
            res["citations"] = []

        ctx.state.graph_result = res
        return LLMSynthesisNode()


@dataclass
class LLMSynthesisNode(BaseNode[AuditState, None, str]):
    async def run(self, ctx: GraphRunContext[AuditState, None]) -> End[str]:
        logger.info("[Graph] Executing LLM Synthesis Node")
        
        nlp = ctx.state.nlp_result or {"flagged": False, "reason": "", "similarity": 1.0, "citations": []}
        anomaly = ctx.state.anomaly_result or {"flagged": False, "reason": "", "loss": 0.0, "threshold": 0.02, "citations": []}
        graph = ctx.state.graph_result or {"flagged": False, "reason": "", "findings": [], "citations": []}

        # 1. Compute threat index
        score = 0.0
        reasons = []
        citations = []

        if nlp.get("flagged"):
            score += 0.35
            reasons.append(f"Tier 1 (NLP): {nlp.get('reason')}")
            citations.extend(nlp.get("citations", []))
        if anomaly.get("flagged"):
            score += 0.35
            reasons.append(f"Tier 2 (ML): {anomaly.get('reason')}")
            citations.extend(anomaly.get("citations", []))
        if graph.get("flagged"):
            score += 0.30
            reasons.append(f"Tier 3 (Graph): {graph.get('reason')}")
            citations.extend(graph.get("citations", []))

        ctx.state.threat_index = round(min(score, 1.0), 2)
        ctx.state.status = "HOLD" if ctx.state.threat_index >= 0.35 else "APPROVE"
        ctx.state.citations = list(set(citations))

        if ctx.state.status == "APPROVE":
            ctx.state.justification = "Claim approved. All payment integrity audits completed successfully."
            ctx.state.next_steps = []
            return End(json.dumps(self._build_payload(ctx.state)))

        # 2. Invoke LLM to generate the final adjudication summary and next steps if pended/HOLD
        reasons_str = "\n".join([f"- {r}" for r in reasons])
        
        prompt = f"""You are an advanced autonomous Payment Integrity Officer at a major health insurance payer.
Your primary task is to review clinical-financial audits and construct a comprehensive, explainable adjudication summary for claims that have been flagged as high-risk (HOLD) by our automated engines.

Adjudication Target Claim Details:
- Patient ID: {ctx.state.patient_id}
- Submitting Provider NPI: {ctx.state.provider_npi}
- Billed CPT Codes: {", ".join(ctx.state.cpt_codes)}
- Total Billed Amount: ${ctx.state.billed_amount:.2f}
- Number of Line Items: {ctx.state.code_count}
- Service Date: {ctx.state.service_date}

Automated Audit Findings:
{reasons_str}

Please generate a professional, detailed, and highly explainable adjudication report.
You must output a structured JSON object containing exactly the following two keys:
1. "justification": a detailed explanation (in markdown) outlining the exact reason codes and metrics, and formally justifying why the claim is being pended ("HOLD").
2. "next_steps": a list of strings representing structured, actionable next steps for the clinical audit queue.

CRITICAL: Do NOT use any emojis or characters outside the Basic Multilingual Plane (characters must fit within the standard regex [\\u0020-\\uFFFF]) in your output.
"""
        try:
            settings = llm_router._load_settings()
            timeout = float(settings.get("timeout", 300.0))
            
            messages_json = json.dumps([{"role": "user", "content": prompt}])
            res_content = llm_router.chat(
                system_prompt="You are a Payment Integrity Agent. Output only valid JSON.",
                messages_json=messages_json,
                max_tokens=1500,
                timeout=timeout,
                response_format={"type": "json_object"}
            )
            
            # Since chat returns a dict with 'content' when tools is not used but wait, let's verify
            # Wait, let's check llm_router.py chat return value when tools is None:
            # It returns `content` string!
            # Let's verify this in llm_router.py.
            # In llm_router.py, when tools is None, it returns `content` string directly!
            # Yes! Let's double check from our git diff:
            # `content = clean_non_bmp(response.choices[0].message.content)`
            # `with _response_cache_lock: ... return content`
            # Yes, it returns a string when tools is None!
            parsed_json = json.loads(res_content)
            ctx.state.justification = parsed_json.get("justification", f"Claim placed on hold. Threat score {ctx.state.threat_index:.2f}.")
            ctx.state.next_steps = parsed_json.get("next_steps", ["Review flagged anomalies manually"])
        except Exception as e:
            logger.error(f"LLM synthesis failed or returned invalid JSON: {str(e)}")
            ctx.state.justification = f"Deterministic audit complete. Claim placed on hold due to flagged anomalies. Threat score {ctx.state.threat_index:.2f}."
            ctx.state.next_steps = ["Review flagged anomalies manually"]

        return End(json.dumps(self._build_payload(ctx.state)))

    def _build_payload(self, state: AuditState) -> dict:
        return {
            "status": state.status,
            "threat_index": state.threat_index,
            "findings": {
                "tier1": {
                    "flagged": state.nlp_result.get("flagged", False) if state.nlp_result else False,
                    "reason": state.nlp_result.get("reason", "") if state.nlp_result else "",
                    "similarity": state.nlp_result.get("similarity", 1.0) if state.nlp_result else 1.0,
                    "citations": state.nlp_result.get("citations", []) if state.nlp_result else []
                },
                "tier2": {
                    "flagged": state.anomaly_result.get("flagged", False) if state.anomaly_result else False,
                    "reason": state.anomaly_result.get("reason", "") if state.anomaly_result else "",
                    "loss": state.anomaly_result.get("loss", 0.0) if state.anomaly_result else 0.0,
                    "threshold": state.anomaly_result.get("threshold", 0.02) if state.anomaly_result else 0.02,
                    "citations": state.anomaly_result.get("citations", []) if state.anomaly_result else []
                },
                "tier3": {
                    "flagged": state.graph_result.get("flagged", False) if state.graph_result else False,
                    "reason": state.graph_result.get("reason", "") if state.graph_result else "",
                    "findings": state.graph_result.get("findings", []) if state.graph_result else [],
                    "citations": state.graph_result.get("citations", []) if state.graph_result else []
                }
            },
            "citations": state.citations,
            "justification": state.justification,
            "next_steps": state.next_steps
        }


# 3. Compile the Graph using GraphBuilder
g = GraphBuilder(state_type=AuditState, output_type=str)

@g.step
async def start(ctx: StepContext[AuditState, None, None]) -> ClaimIngestionNode:
    return ClaimIngestionNode()

g.add(
    g.node(ClaimIngestionNode),
    g.node(ClinicalAuditNode),
    g.node(AnomalyAuditNode),
    g.node(NetworkAuditNode),
    g.node(LLMSynthesisNode),
    g.edge_from(g.start_node).to(start)
)

audit_graph = g.build()

async def execute_graph_audit(patient_id: str, provider_npi: str, cpt_codes: list, cpt_displays: list, icd_codes: list,
                              billed_amount: float, code_count: int, specialty_code: float, patient_age: float, duration_days: float,
                              service_date: str = None, claim_id: str = None) -> str:
    """Entry point to run the compiled Pydantic Graph FSM for claim adjudication."""
    state = AuditState(
        claim_id=claim_id,
        patient_id=patient_id,
        provider_npi=provider_npi,
        billed_amount=float(billed_amount),
        cpt_codes=cpt_codes,
        cpt_displays=cpt_displays,
        icd_codes=icd_codes,
        code_count=int(code_count),
        specialty_code=float(specialty_code),
        patient_age=float(patient_age),
        duration_days=float(duration_days),
        service_date=service_date
    )
    result = await audit_graph.run(state=state)
    return result
