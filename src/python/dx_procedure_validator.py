"""Diagnosis-to-Procedure Code Validation.

Validates that ICD-10 diagnosis codes support the billed CPT procedure,
flagging unsupported combinations for manual review.
"""

# ICD-10 chapter → CPT range validation rules
# Format: (icd_prefix, cpt_low, cpt_high, description)
_VALIDATION_RULES = [
    # Mental/Behavioral disorders (F00-F99) → Psychiatric/Evaluation codes
    ("F", 90791, 90899, "Psychiatric diagnostic evaluation and psychotherapy"),
    ("F", 99201, 99215, "Evaluation and management — office visit"),

    # Circulatory system (I00-I99) → Cardiovascular procedures
    ("I", 92920, 93799, "Cardiovascular therapeutic and diagnostic procedures"),
    ("I", 99201, 99215, "Evaluation and management — office visit"),
    ("I", 93000, 93018, "Electrocardiogram"),

    # Respiratory system (J00-J99) → Pulmonary procedures
    ("J", 94010, 94799, "Pulmonary diagnostic and therapeutic procedures"),
    ("J", 99201, 99215, "Evaluation and management — office visit"),

    # Musculoskeletal (M00-M99) → Orthopedic/Physical medicine
    ("M", 20550, 20999, "General musculoskeletal procedures"),
    ("M", 97010, 97799, "Physical medicine and rehabilitation"),
    ("M", 99201, 99215, "Evaluation and management — office visit"),

    # Nervous system (G00-G99) → Neurological procedures
    ("G", 95700, 96020, "Neurology and neuromuscular procedures"),
    ("G", 99201, 99215, "Evaluation and management — office visit"),

    # Neoplasms (C00-D49) → Surgical pathology, oncology
    ("C", 88300, 88399, "Surgical pathology"),
    ("C", 99201, 99215, "Evaluation and management — office visit"),

    # Injury/Poisoning (S00-T88) → Surgical, emergency
    ("S", 10021, 69990, "Surgical procedures"),
    ("S", 99281, 99285, "Emergency department visit"),
    ("T", 10021, 69990, "Surgical procedures"),
    ("T", 99281, 99285, "Emergency department visit"),

    # Endocrine/Nutritional/Metabolic (E00-E89) → Lab, E&M
    ("E", 80047, 89398, "Pathology and laboratory"),
    ("E", 99201, 99215, "Evaluation and management — office visit"),

    # Digestive system (K00-K95) → Gastroenterology
    ("K", 43200, 45399, "Gastroenterology endoscopic procedures"),
    ("K", 99201, 99215, "Evaluation and management — office visit"),

    # Factors influencing health (Z00-Z99) → Preventive/Administrative
    ("Z", 99381, 99429, "Preventive medicine services"),
    ("Z", 99201, 99215, "Evaluation and management — office visit"),
]


def _parse_cpt_code(cpt_str: str) -> int:
    """Extract numeric CPT code from string like 'CPT 99214 - Office visit'."""
    import re
    match = re.search(r'(\d{4,5})', cpt_str)
    return int(match.group(1)) if match else 0


def _parse_icd_prefix(icd_str: str) -> str:
    """Extract ICD-10 chapter letter from code string."""
    if icd_str and len(icd_str) > 0:
        return icd_str[0].upper()
    return ""


def validate_diagnosis_procedure(icd_code: str, cpt_code_str: str) -> dict:
    """Check if ICD diagnosis supports billed CPT procedure.

    Returns: {
        "valid": bool,
        "icd_code": str,
        "cpt_code": int,
        "matched_rules": list,
        "flagged": bool,
        "reason": str,
    }
    """
    if not icd_code or not cpt_code_str:
        return {
            "valid": True,
            "icd_code": icd_code or "",
            "cpt_code": 0,
            "matched_rules": [],
            "flagged": False,
            "reason": "Insufficient code data for validation",
        }

    cpt_num = _parse_cpt_code(cpt_code_str)
    icd_prefix = _parse_icd_prefix(icd_code)

    if cpt_num == 0 or icd_prefix == "":
        return {
            "valid": True,
            "icd_code": icd_code,
            "cpt_code": cpt_num,
            "matched_rules": [],
            "flagged": False,
            "reason": "Could not parse codes for validation",
        }

    matched = []
    for rule_prefix, cpt_low, cpt_high, desc in _VALIDATION_RULES:
        if rule_prefix == icd_prefix and cpt_low <= cpt_num <= cpt_high:
            matched.append({
                "icd_chapter": rule_prefix,
                "cpt_range": f"{cpt_low}-{cpt_high}",
                "description": desc,
            })

    if not matched:
        return {
            "valid": False,
            "icd_code": icd_code,
            "cpt_code": cpt_num,
            "matched_rules": [],
            "flagged": True,
            "reason": f"Diagnosis code {icd_code} (ICD-10 chapter {icd_prefix}) does not support billed CPT procedure {cpt_num}. Possible upcoding or diagnostic mismatch.",
        }

    return {
        "valid": True,
        "icd_code": icd_code,
        "cpt_code": cpt_num,
        "matched_rules": matched,
        "flagged": False,
        "reason": f"Diagnosis {icd_code} supports {cpt_num} ({', '.join(m['description'] for m in matched)})",
    }
