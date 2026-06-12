# Diagnosis-Procedure Validator

> The Diagnosis-Procedure Validator (`dx_procedure_validator.py`) checks whether a billed CPT procedure is medically justified by the patient's ICD-10 diagnosis code, flagging unsupported combinations for manual review.

## Validation Rules

The validator uses a rule-based mapping from ICD-10 chapter letter prefixes to allowable CPT code ranges. Each rule specifies which ICD chapter supports which procedure range:

| ICD Prefix | ICD Chapter | Allowed CPT Range | Typical Procedures |
|:----------:|-------------|:-----------------:|--------------------|
| `F` | Mental/Behavioral (F00-F99) | 90791–90899 | Psychiatric eval, psychotherapy |
| `F` | Mental/Behavioral | 99201–99215 | Office E&M |
| `I` | Circulatory (I00-I99) | 92920–93799 | Cardiovascular therapeutic/diagnostic |
| `I` | Circulatory | 99201–99215 | Office E&M |
| `I` | Circulatory | 93000–93018 | ECG |
| `J` | Respiratory (J00-J99) | 94010–94799 | Pulmonary diagnostic/therapeutic |
| `J` | Respiratory | 99201–99215 | Office E&M |
| `M` | Musculoskeletal (M00-M99) | 20550–20999 | General musculoskeletal |
| `M` | Musculoskeletal | 97010–97799 | Physical medicine & rehab |
| `M` | Musculoskeletal | 99201–99215 | Office E&M |
| `G` | Nervous (G00-G99) | 95700–96020 | Neurology & neuromuscular |
| `G` | Nervous | 99201–99215 | Office E&M |
| `C` | Neoplasms (C00-D49) | 88300–88399 | Surgical pathology |
| `C` | Neoplasms | 99201–99215 | Office E&M |
| `S` | Injury (S00-T88) | 10021–69990 | Surgical procedures |
| `S` | Injury | 99281–99285 | Emergency department |
| `T` | External causes (T00-T88) | 10021–69990 | Surgical procedures |
| `T` | External causes | 99281–99285 | Emergency department |
| `E` | Endocrine/Metabolic (E00-E89) | 80047–89398 | Pathology & laboratory |
| `E` | Endocrine/Metabolic | 99201–99215 | Office E&M |
| `K` | Digestive (K00-K95) | 43200–45399 | Gastroenterology endoscopic |
| `K` | Digestive | 99201–99215 | Office E&M |
| `Z` | Factors (Z00-Z99) | 99381–99429 | Preventive medicine |
| `Z` | Factors | 99201–99215 | Office E&M |

## How It Works

```
Input: ICD-10 code "I10", CPT string "CPT 99214 - Office visit"
         │
         ▼
Extract ICD prefix: "I"
Extract CPT numeric: 99214
         │
         ▼
Match against rules:
  "I" + 92920-93799 → no (99214 not in range)
  "I" + 99201-99215 → yes ✓
         │
         ▼
Return: { valid: true, matched_rules: ["Evaluation and management — office visit"] }
```

## Response Format

```json
{
  "valid": true,
  "icd_code": "I10",
  "cpt_code": 99214,
  "matched_rules": [
    {
      "icd_chapter": "I",
      "cpt_range": "99201-99215",
      "description": "Evaluation and management — office visit"
    }
  ],
  "flagged": false,
  "reason": "Diagnosis I10 supports 99214 (Evaluation and management — office visit)"
}
```

A `valid: false` result with `flagged: true` indicates a potential upcoding or diagnostic mismatch and triggers an audit flag.

## Edge Cases

- **Missing codes**: Returns `valid: true` with `reason: "Insufficient code data"` — does not flag claims lacking code data.
- **Unparseable codes**: Returns `valid: true` with `reason: "Could not parse codes"` — lenient toward non-standard formatting.
- **Unmatched diagnosis**: Returns `valid: false` with a detailed reason explaining which ICD chapter was tested and why no CPT rules matched.

## Usage

The validator is called in two contexts:
- **Directly** via `dx_procedure_validator.validate_diagnosis_procedure(icd_code, cpt_code_str)`
- **Via the tool registry** as `validate_clinical_edits` — accessible to the agent loop (see [[Agent Tool Registry]])

## See Also

[[Agent Tool Registry]] · [[LLM Router Architecture]] · [[Tier 1 - Semantic Clinical Auditor]]
