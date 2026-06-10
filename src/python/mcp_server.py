import sys
import os
from mcp.server.fastmcp import FastMCP

# Ensure the parent directory is in python path to load sibling modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import dx_procedure_validator

# Initialize the server
mcp = FastMCP("Claim Terminology Resolver")

# Predefined medical terminology dictionaries
CPT_CODES = {
    "99203": "Office or other outpatient visit for the evaluation and management of a new patient (moderate level of medical decision making).",
    "99204": "Office or other outpatient visit for the evaluation and management of a new patient (high level of medical decision making).",
    "99213": "Office or other outpatient visit for the evaluation and management of an established patient (low-to-moderate level of medical decision making).",
    "99214": "Office or other outpatient visit for the evaluation and management of an established patient (moderate-to-high level of medical decision making).",
    "99215": "Office or other outpatient visit for the evaluation and management of an established patient (high level of medical decision making).",
    "93000": "Electrocardiogram (ECG/EKG), tracing only, without interpretation and report.",
    "93005": "Electrocardiogram (ECG/EKG), tracing and interpretation.",
    "93010": "Electrocardiogram (ECG/EKG), interpretation and report only.",
    "94010": "Spirometry, including graphic record, total and timed vital capacity, expiratory flow rate measurement(s), with or without maximal voluntary ventilation.",
    "90791": "Psychiatric diagnostic evaluation without medical services.",
    "90834": "Psychotherapy, 45 minutes with patient.",
    "97110": "Therapeutic procedure, 1 or more areas, each 15 minutes; therapeutic exercises to develop strength and endurance, range of motion and flexibility.",
    "20552": "Injection(s); single or multiple trigger point(s), 1 or 2 muscle(s).",
    "80053": "Comprehensive metabolic panel (laboratory test).",
    "85025": "Complete blood count (hemogram and platelet count), automated, and automated differential WBC count.",
}

ICD_CODES = {
    "I10": "Essential (primary) hypertension",
    "E11.9": "Type 2 diabetes mellitus without complications",
    "F32.9": "Major depressive disorder, single episode, unspecified",
    "J45.909": "Unspecified asthma, uncomplicated",
    "M25.562": "Pain in left knee",
    "M54.5": "Low back pain",
    "G43.909": "Migraine, unspecified, not intractable, without status migraine",
    "Z00.00": "Encounter for general adult medical examination without abnormal findings",
    "C34.90": "Malignant neoplasm of unspecified part of unspecified bronchus or lung",
}

@mcp.tool()
def lookup_cpt_code(code: str) -> str:
    """Look up a CPT (Current Procedural Terminology) code's official description.
    
    Args:
        code: The 5-digit CPT code (e.g., '99214').
    """
    clean_code = code.strip()
    desc = CPT_CODES.get(clean_code)
    if desc:
        return f"CPT Code {clean_code}: {desc}"
    return f"CPT Code {clean_code}: Description not found in terminology database."

@mcp.tool()
def lookup_icd_code(code: str) -> str:
    """Look up an ICD-10 (International Classification of Diseases, 10th Revision) diagnosis code description.
    
    Args:
        code: The ICD-10 code (e.g., 'I10').
    """
    clean_code = code.strip().upper()
    desc = ICD_CODES.get(clean_code)
    if not desc:
        # Check if the prefix (e.g. 'E11') exists in keys
        for k, v in ICD_CODES.items():
            if clean_code.startswith(k) or k.startswith(clean_code):
                desc = f"{v} (matched on prefix {k})"
                break
    if desc:
        return f"ICD-10 Code {clean_code}: {desc}"
    return f"ICD-10 Code {clean_code}: Description not found in terminology database."

@mcp.tool()
def validate_diagnosis_procedure(icd_code: str, cpt_code: str) -> str:
    """Validate diagnosis and procedure compatibility to detect upcoding or mismatch.
    
    Args:
        icd_code: The ICD-10 diagnosis code.
        cpt_code: The CPT procedure code.
    """
    res = dx_procedure_validator.validate_diagnosis_procedure(icd_code, cpt_code)
    if res.get("flagged", False):
        return f"INVALID: {res.get('reason')}"
    return f"VALID: {res.get('reason')}"

if __name__ == "__main__":
    # Run server on stdio transport
    mcp.run(transport="stdio")
