"""Agent tools registry and definitions for the ClaimAuditAI Agentic Framework."""
import os
import sys
import json
import inspect
from typing import Callable, Dict, List, Any

# Ensure parent directory is in path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

try:
    import iris
except ImportError:
    iris = None

# Import existing audit and validation modules
import nlp_auditor
import autoencoder_train
import graph_analyzer
import dx_procedure_validator
import mcp_server

# Tool Registry class
class ToolRegistry:
    def __init__(self):
        self._tools: Dict[str, Callable] = {}
        self._schemas: Dict[str, Dict[str, Any]] = {}

    def register(self, func: Callable) -> Callable:
        """Register a function as a tool and auto-generate its LLM schema."""
        name = func.__name__
        doc = inspect.getdoc(func) or ""
        
        # Parse docstring for description (take everything before 'Args:')
        desc = doc.split("Args:")[0].strip()
        
        # Build function parameters schema using reflection
        sig = inspect.signature(func)
        properties = {}
        required = []
        
        for param_name, param in sig.parameters.items():
            param_type = "string"
            if param.annotation == float:
                param_type = "number"
            elif param.annotation == int:
                param_type = "integer"
            elif param.annotation == bool:
                param_type = "boolean"
            elif param.annotation == list or param.annotation == List[str]:
                param_type = "array"
                
            properties[param_name] = {
                "type": param_type,
                "description": f"The {param_name} parameter."
            }
            if param.default == inspect.Parameter.empty:
                required.append(param_name)

        schema = {
            "type": "function",
            "function": {
                "name": name,
                "description": desc,
                "parameters": {
                    "type": "object",
                    "properties": properties,
                    "required": required
                }
            }
        }
        
        self._tools[name] = func
        self._schemas[name] = schema
        return func

    def get_tool(self, name: str) -> Callable:
        return self._tools.get(name)

    def get_all_schemas(self) -> List[Dict[str, Any]]:
        return list(self._schemas.values())

    def execute(self, name: str, arguments: Dict[str, Any]) -> str:
        """Execute a tool by name with arguments and return the stringified result."""
        tool_func = self.get_tool(name)
        if not tool_func:
            return f"Error: Tool '{name}' not found in registry."
        try:
            res = tool_func(**arguments)
            if isinstance(res, (dict, list)):
                return json.dumps(res, indent=2)
            return str(res)
        except Exception as e:
            return f"Error executing tool '{name}': {str(e)}"

# Instantiate the global tool registry
registry = ToolRegistry()

# --- Register Agent Tools ---

@registry.register
def lookup_cpt_code(code: str) -> str:
    """Look up a CPT (Current Procedural Terminology) code's official description.
    
    Args:
        code: The 5-digit CPT code (e.g., '99214').
    """
    return mcp_server.lookup_cpt_code(code)

@registry.register
def lookup_icd_code(code: str) -> str:
    """Look up an ICD-10 (International Classification of Diseases) diagnosis code's official description.
    
    Args:
        code: The ICD-10 code (e.g., 'I10').
    """
    return mcp_server.lookup_icd_code(code)

@registry.register
def validate_clinical_edits(icd_code: str, cpt_code: str) -> str:
    """Validate diagnosis and procedure compatibility to detect upcoding or mismatch.
    
    Args:
        icd_code: The ICD-10 diagnosis code.
        cpt_code: The CPT procedure code.
    """
    return mcp_server.validate_diagnosis_procedure(icd_code, cpt_code)

@registry.register
def run_nlp_audit(patient_id: str, cpt_displays: List[str], service_date: str = None) -> str:
    """Run the NLP clinical document search to verify documented note support for billed CPT codes.
    
    Args:
        patient_id: The patient ID.
        cpt_displays: List of procedure descriptions to search for.
        service_date: Optional service date.
    """
    try:
        res = nlp_auditor.verify_clinical_validity(patient_id, cpt_displays, service_date=service_date)
        return json.dumps(res, indent=2)
    except Exception as e:
        return f"NLP Audit execution error: {str(e)}"

@registry.register
def run_anomaly_audit(billed_amount: float, code_count: float, specialty_code: float, patient_age: float, duration_days: float) -> str:
    """Evaluate if the claim's billed features (amount, count, specialty) represent a statistical anomaly.
    
    Args:
        billed_amount: Total billed amount.
        code_count: Number of line items on claim.
        specialty_code: The numeric specialty code.
        patient_age: Age of the patient.
        duration_days: Duration of the billable encounter.
    """
    try:
        res = autoencoder_train.evaluate_claim_anomaly(
            billed_amount, code_count, specialty_code, patient_age, duration_days
        )
        return json.dumps(res, indent=2)
    except Exception as e:
        return f"Anomaly Audit execution error: {str(e)}"

@registry.register
def run_graph_audit(patient_id: str, provider_npi: str, service_date: str = None) -> str:
    """Run collusion network analysis to scan patient-provider topology for loops or anomalies.
    
    Args:
        patient_id: The patient ID.
        provider_npi: The provider's NPI.
        service_date: Optional service date.
    """
    try:
        res = graph_analyzer.check_collusion_network(patient_id, provider_npi, service_date)
        return json.dumps(res, indent=2)
    except Exception as e:
        return f"Graph Audit execution error: {str(e)}"

@registry.register
def get_patient_history(patient_id: str) -> str:
    """Retrieve historical claim decisions and outcomes for a specific patient.
    
    Args:
        patient_id: The unique patient identifier (e.g., '123' or 'Patient/123').
    """
    if iris is None:
        return "Query skipped: IRIS environment is not loaded."
    try:
        clean_id = patient_id.replace("Patient/", "")
        stmt = iris.sql.prepare("SELECT Key, outcome, disposition, _lastUpdated FROM HSFHIR_X0001_S.ClaimResponse WHERE patient = ?")
        rs = stmt.execute(f"Patient/{clean_id}")
        history = []
        for row in rs:
            history.append({
                "claim_response_id": row[0],
                "outcome": row[1],
                "disposition": row[2],
                "timestamp": row[3]
            })
        return json.dumps(history, indent=2)
    except Exception as e:
        return f"Error querying patient history: {str(e)}"

@registry.register
def get_provider_history(provider_npi: str) -> str:
    """Retrieve historical audit hold, approve, and reject rates for a specific provider.
    
    Args:
        provider_npi: The unique provider NPI.
    """
    if iris is None:
        return "Query skipped: IRIS environment is not loaded."
    try:
        clean_npi = provider_npi.replace("Practitioner/", "")
        stmt = iris.sql.prepare(
            "SELECT CR.outcome, COUNT(*) FROM HSFHIR_X0001_S.ClaimResponse CR "
            "JOIN HSFHIR_X0001_S.Claim C ON CR.request = C.Key "
            "WHERE C.provider = ? "
            "GROUP BY CR.outcome"
        )
        rs = stmt.execute(f"Practitioner/{clean_npi}")
        history = {}
        for row in rs:
            history[row[0]] = int(row[1])
        return json.dumps(history, indent=2)
    except Exception as e:
        return f"Error querying provider history: {str(e)}"
