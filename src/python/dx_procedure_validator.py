"""Diagnosis-to-Procedure Code Validation.

Validates that ICD-10 diagnosis codes support the billed CPT procedure,
flagging unsupported combinations for manual review.
Based on CMS NCCI procedure-to-diagnosis edit concepts.
"""

# ICD-10 chapter → CPT range validation rules
# Format: (icd_prefix, cpt_low, cpt_high, description)
# Organized by ICD-10 chapter with appropriate CPT ranges
_VALIDATION_RULES = [
    # A00-B99: Infectious/Parasitic → Lab, E&M, minor procedures
    ("A", 80047, 89398, "Pathology and laboratory testing"),
    ("A", 87001, 87999, "Microbiology and infectious agent detection"),
    ("A", 99201, 99215, "Evaluation and management"),
    ("A", 99281, 99285, "Emergency department visit"),
    ("A", 96360, 96549, "Therapeutic infusion and injection"),
    ("A", 10021, 10160, "Incision and drainage procedures"),
    ("B", 80047, 89398, "Pathology and laboratory testing"),
    ("B", 87001, 87999, "Microbiology and infectious agent detection"),
    ("B", 99201, 99215, "Evaluation and management"),
    ("B", 99281, 99285, "Emergency department visit"),
    ("B", 96360, 96549, "Therapeutic infusion and injection"),

    # C00-D49: Neoplasms → Oncology, surgical pathology, imaging
    ("C", 10021, 19499, "Surgical procedures — integumentary"),
    ("C", 20000, 29999, "Surgical procedures — musculoskeletal"),
    ("C", 30000, 32999, "Surgical procedures — respiratory"),
    ("C", 33000, 37799, "Surgical procedures — cardiovascular"),
    ("C", 38100, 38999, "Surgical procedures — lymphatic/mediastinum"),
    ("C", 40490, 49999, "Surgical procedures — digestive"),
    ("C", 50010, 53899, "Surgical procedures — urinary"),
    ("C", 54000, 55899, "Surgical procedures — male genital"),
    ("C", 55900, 58999, "Surgical procedures — female genital"),
    ("C", 60000, 60699, "Surgical procedures — endocrine"),
    ("C", 61000, 64999, "Surgical procedures — nervous system"),
    ("C", 65000, 68899, "Surgical procedures — eye/ocular adnexa"),
    ("C", 69000, 69990, "Surgical procedures — ear/mastoid"),
    ("C", 70010, 76499, "Diagnostic radiology"),
    ("C", 77001, 77014, "Radiation oncology simulation"),
    ("C", 77261, 77799, "Radiation oncology treatment"),
    ("C", 78000, 79999, "Nuclear medicine"),
    ("C", 80047, 89398, "Pathology and laboratory — histopathology"),
    ("C", 88104, 88199, "Cytopathology"),
    ("C", 88300, 88399, "Surgical pathology"),
    ("C", 99201, 99215, "Evaluation and management"),
    ("C", 99281, 99285, "Emergency department visit"),
    ("C", 99381, 99429, "Preventive medicine services"),
    ("D", 80047, 89398, "Pathology and laboratory testing"),
    ("D", 85002, 85999, "Hematology and coagulation"),
    ("D", 88104, 88199, "Cytopathology"),
    ("D", 88300, 88399, "Surgical pathology"),
    ("D", 99201, 99215, "Evaluation and management"),
    ("D", 99281, 99285, "Emergency department visit"),
    ("D", 96360, 96549, "Therapeutic infusion and injection"),

    # E00-E89: Endocrine/Metabolic → Lab, E&M, imaging
    ("E", 80047, 89398, "Pathology and laboratory testing"),
    ("E", 81000, 81099, "Urinalysis"),
    ("E", 82947, 82985, "Glucose and endocrine testing"),
    ("E", 84436, 84490, "Thyroid and endocrine testing"),
    ("E", 70010, 76499, "Diagnostic radiology"),
    ("E", 76506, 76999, "Ultrasound"),
    ("E", 78000, 79999, "Nuclear medicine"),
    ("E", 99201, 99215, "Evaluation and management"),
    ("E", 99281, 99285, "Emergency department visit"),
    ("E", 60000, 60699, "Endocrine surgical procedures"),
    ("E", 96360, 96549, "Therapeutic infusion and injection"),
    ("E", 95250, 95251, "Continuous glucose monitoring"),
    ("E", 99381, 99429, "Preventive medicine services"),

    # F01-F99: Mental/Behavioral → Psychiatric, E&M
    ("F", 90785, 90899, "Psychiatric diagnostic and psychotherapy"),
    ("F", 96101, 96140, "Psychological and neuropsychological testing"),
    ("F", 96150, 96155, "Health and behavior assessment"),
    ("F", 97151, 97158, "Adaptive behavior treatment"),
    ("F", 99201, 99215, "Evaluation and management"),
    ("F", 99281, 99285, "Emergency department visit"),
    ("F", 99304, 99318, "Nursing facility evaluation"),
    ("F", 99401, 99412, "Preventive counseling"),
    ("F", 99483, 99484, "Cognitive assessment and care planning"),
    ("F", "H0001", "H0049", "Alcohol and drug abuse treatment"),
    ("F", "H1000", "H1002", "Prenatal drug screening"),

    # G00-G99: Nervous System → Neurological, E&M
    ("G", 61000, 64999, "Neurological surgical procedures"),
    ("G", 64400, 64999, "Pain management injections"),
    ("G", 95700, 96020, "Neurology and neuromuscular procedures"),
    ("G", 95812, 95827, "Sleep medicine testing"),
    ("G", 95831, 95999, "Neurological diagnostic procedures"),
    ("G", 95965, 95967, "Evoked potential testing"),
    ("G", 95990, 95992, "Nerve conduction studies"),
    ("G", 96040, 96040, "Medical genetics counseling"),
    ("G", 96116, 96121, "Neurobehavioral status exam"),
    ("G", 99201, 99215, "Evaluation and management"),
    ("G", 99281, 99285, "Emergency department visit"),
    ("G", 70010, 76499, "Diagnostic radiology — neuroimaging"),
    ("G", 70450, 70498, "CT head and neck"),
    ("G", 70540, 70559, "MRI head and neck"),
    ("G", 78000, 79999, "Nuclear medicine — brain imaging"),
    ("G", 93880, 93931, "Noninvasive vascular studies — cerebrovascular"),

    # H00-H59: Eye → Ophthalmic procedures
    ("H", 65091, 68899, "Ophthalmic surgical procedures"),
    ("H0", 65091, 68899, "Ophthalmic surgical procedures"),
    ("H1", 65091, 68899, "Ophthalmic surgical procedures"),
    ("H2", 65091, 68899, "Ophthalmic surgical procedures"),
    ("H3", 65091, 68899, "Ophthalmic surgical procedures"),
    ("H4", 65091, 68899, "Ophthalmic surgical procedures"),
    ("H5", 65091, 68899, "Ophthalmic surgical procedures"),
    ("H", 92002, 92499, "Ophthalmological diagnostic and treatment"),
    ("H", 76506, 76999, "Ophthalmic ultrasound"),
    ("H", 92201, 92285, "Ophthalmic imaging"),
    ("H", 99201, 99215, "Evaluation and management"),
    ("H", 99281, 99285, "Emergency department visit"),
    ("H6", 69000, 69990, "Otological surgical procedures"),
    ("H7", 69000, 69990, "Otological surgical procedures"),
    ("H8", 69000, 69990, "Otological surgical procedures"),
    ("H9", 69000, 69990, "Otological surgical procedures"),
    ("H6", 92502, 92700, "Otological diagnostic procedures"),
    ("H7", 92502, 92700, "Otological diagnostic procedures"),
    ("H8", 92502, 92700, "Otological diagnostic procedures"),
    ("H9", 92502, 92700, "Otological diagnostic procedures"),
    ("H6", 99201, 99215, "Evaluation and management"),
    ("H7", 99201, 99215, "Evaluation and management"),
    ("H8", 99201, 99215, "Evaluation and management"),
    ("H9", 99201, 99215, "Evaluation and management"),

    # I00-I99: Circulatory → Cardiovascular procedures
    ("I", 92920, 92997, "Cardiovascular therapeutic procedures"),
    ("I", 92998, 93799, "Cardiovascular diagnostic and monitoring"),
    ("I", 93000, 93018, "Electrocardiogram"),
    ("I", 93040, 93299, "Cardiovascular monitoring devices"),
    ("I", 93303, 93355, "Echocardiography"),
    ("I", 93503, 93533, "Cardiac catheterization"),
    ("I", 93590, 93662, "Electrophysiology procedures"),
    ("I", 93701, 93799, "Noninvasive vascular studies"),
    ("I", 93880, 93931, "Vascular ultrasound studies"),
    ("I", 93970, 93998, "Venous and arterial studies"),
    ("I", 99201, 99215, "Evaluation and management"),
    ("I", 99281, 99285, "Emergency department visit"),
    ("I", 33010, 37799, "Cardiovascular surgical procedures"),
    ("I", 70010, 76499, "Diagnostic radiology — vascular imaging"),
    ("I", 78000, 79999, "Nuclear medicine — cardiac imaging"),
    ("I", 80047, 89398, "Laboratory — cardiac biomarkers"),

    # J00-J99: Respiratory → Pulmonary procedures
    ("J", 30000, 32999, "Respiratory surgical procedures"),
    ("J", 94010, 94799, "Pulmonary diagnostic and therapeutic"),
    ("J", 94640, 94669, "Pulmonary therapeutics and airway management"),
    ("J", 95004, 95099, "Allergy testing"),
    ("J", 95115, 95199, "Allergen immunotherapy"),
    ("J", 99201, 99215, "Evaluation and management"),
    ("J", 99281, 99285, "Emergency department visit"),
    ("J", 70010, 76499, "Diagnostic radiology — chest imaging"),
    ("J", 71045, 71048, "Chest X-ray"),
    ("J", 71250, 71275, "CT chest"),
    ("J", 78000, 79999, "Nuclear medicine — pulmonary"),
    ("J", 80047, 89398, "Laboratory — respiratory function"),
    ("J", 94620, 94621, "Pulmonary stress testing"),

    # K00-K95: Digestive → Gastroenterology
    ("K", 40490, 43999, "Oral and gastrointestinal surgical"),
    ("K", 43200, 43289, "Esophageal/upper GI endoscopy"),
    ("K", 43235, 43270, "Upper GI endoscopy with interventions"),
    ("K", 43450, 43460, "Esophageal dilation and procedures"),
    ("K", 43752, 43762, "Gastric intubation and tube placement"),
    ("K", 44100, 44188, "Intestinal incision and excision"),
    ("K", 44360, 44397, "Small intestine endoscopy"),
    ("K", 44700, 44799, "Intestinal procedures"),
    ("K", 45000, 45999, "Anorectal procedures"),
    ("K", 45300, 45399, "Lower GI endoscopy (colonoscopy)"),
    ("K", 46020, 46999, "Anorectal surgical procedures"),
    ("K", 47000, 47999, "Hepatobiliary procedures"),
    ("K", 48000, 48999, "Pancreatic surgical procedures"),
    ("K", 49000, 49999, "Abdominal surgical procedures"),
    ("K", 70010, 76499, "Diagnostic radiology — abdominal imaging"),
    ("K", 74150, 74178, "CT abdomen/pelvis"),
    ("K", 76700, 76776, "Abdominal ultrasound"),
    ("K", 91200, 91299, "Gastroenterology diagnostic"),
    ("K", 99201, 99215, "Evaluation and management"),
    ("K", 99281, 99285, "Emergency department visit"),
    ("K", 80047, 89398, "Laboratory — hepatic function"),

    # L00-L99: Skin → Dermatologic procedures
    ("L", 10021, 19499, "Integumentary surgical procedures"),
    ("L", 11000, 11057, "Debridement and excision"),
    ("L", 11100, 11107, "Skin biopsy"),
    ("L", 11300, 11313, "Shave removal of lesions"),
    ("L", 11400, 11646, "Excision of skin lesions"),
    ("L", 11719, 11772, "Nail procedures"),
    ("L", 11900, 11983, "Injection and removal procedures"),
    ("L", 12001, 13160, "Wound repair"),
    ("L", 14000, 15738, "Skin grafts and flaps"),
    ("L", 15780, 15879, "Cosmetic and reconstructive procedures"),
    ("L", 15920, 15999, "Pressure ulcer procedures"),
    ("L", 16000, 16036, "Burn treatment"),
    ("L", 17000, 17250, "Destruction of lesions"),
    ("L", 17311, 17391, "Mohs surgery"),
    ("L", 19100, 19499, "Breast surgical procedures"),
    ("L", 96900, 96999, "Dermatological therapeutic procedures"),
    ("L", 99201, 99215, "Evaluation and management"),
    ("L", 99281, 99285, "Emergency department visit"),

    # M00-M99: Musculoskeletal → Orthopedic procedures
    ("M", 20000, 29999, "Musculoskeletal surgical procedures"),
    ("M", 20500, 20555, "Injection and aspiration procedures"),
    ("M", 20600, 20697, "Joint and bursa procedures"),
    ("M", 20900, 20999, "Bone grafting and tissue procedures"),
    ("M", 21010, 21499, "Head and facial surgical procedures"),
    ("M", 21501, 21899, "Neck and chest wall procedures"),
    ("M", 22100, 22899, "Spine surgical procedures"),
    ("M", 22900, 22999, "Abdomen/flank surgical"),
    ("M", 23000, 23929, "Shoulder surgical procedures"),
    ("M", 24000, 24999, "Upper arm/elbow surgical procedures"),
    ("M", 25000, 25999, "Forearm/wrist surgical procedures"),
    ("M", 26010, 26989, "Hand/finger surgical procedures"),
    ("M", 27000, 27999, "Pelvis/hip surgical procedures"),
    ("M", 28001, 28899, "Foot/toe surgical procedures"),
    ("M", 29000, 29799, "Casting and strapping"),
    ("M", 73000, 73660, "Diagnostic radiology — orthopedic"),
    ("M", 73700, 73722, "CT and MRI — orthopedic"),
    ("M", 76870, 76887, "Ultrasound — orthopedic"),
    ("M", 77072, 77081, "Bone density studies"),
    ("M", 97001, 97002, "Physical therapy evaluation"),
    ("M", 97110, 97799, "Physical medicine and rehabilitation"),
    ("M", 97802, 97804, "Medical nutrition therapy"),
    ("M", 98940, 98943, "Chiropractic manipulative treatment"),
    ("M", 99201, 99215, "Evaluation and management"),
    ("M", 99281, 99285, "Emergency department visit"),

    # N00-N99: Genitourinary → Urology/Nephrology
    ("N", 50010, 53899, "Urinary surgical procedures"),
    ("N", 54000, 55899, "Male genital surgical procedures"),
    ("N", 55900, 55980, "Intersex surgery"),
    ("N", 80047, 89398, "Laboratory — renal function"),
    ("N", 81000, 81099, "Urinalysis"),
    ("N", 82000, 82024, "Renal function testing"),
    ("N", 90901, 90999, "Dialysis and renal services"),
    ("N", 94001, 94005, "Sleep studies for renal"),
    ("N", 99201, 99215, "Evaluation and management"),
    ("N", 99281, 99285, "Emergency department visit"),
    ("N", 70010, 76499, "Diagnostic radiology — GU imaging"),
    ("N", 76770, 76776, "Renal ultrasound"),
    ("N", 78700, 78799, "Nuclear medicine — renal"),

    # O00-O9A: Pregnancy/Obstetric → OB procedures
    ("O", 59000, 59899, "Obstetric surgical and diagnostic procedures"),
    ("O", 59050, 59051, "Fetal monitoring"),
    ("O", 59100, 59160, "Ectopic pregnancy procedures"),
    ("O", 59200, 59200, "Cervical dilation"),
    ("O", 59300, 59350, "Obstetric cervical procedures"),
    ("O", 59400, 59430, "Vaginal delivery services"),
    ("O", 59510, 59525, "Cesarean delivery services"),
    ("O", 59610, 59622, "VBAC services"),
    ("O", 59812, 59857, "Pregnancy termination procedures"),
    ("O", 76801, 76828, "Obstetric ultrasound"),
    ("O", 80055, 80055, "Obstetric panel"),
    ("O", 81162, 81479, "Prenatal genetic testing"),
    ("O", 82105, 82106, "AFP and prenatal screening"),
    ("O", 99201, 99215, "Evaluation and management"),
    ("O", 99281, 99285, "Emergency department visit"),
    ("O", 99381, 99429, "Preventive medicine — prenatal"),
    ("O", 99501, 99507, "Home visit for postpartum care"),

    # P00-P96: Perinatal → Neonatal procedures
    ("P", 99201, 99215, "Evaluation and management — neonatal"),
    ("P", 99221, 99239, "Hospital inpatient services"),
    ("P", 99460, 99469, "Newborn care services"),
    ("P", 99477, 99486, "Neonatal critical care"),
    ("P", 31500, 31502, "Neonatal intubation"),
    ("P", 36450, 36456, "Neonatal transfusion"),
    ("P", 36660, 36660, "Neonatal arterial puncture"),
    ("P", 80047, 89398, "Laboratory — neonatal screening"),
    ("P", 84030, 84030, "Newborn phenylalanine test"),

    # Q00-Q99: Congenital → Pediatric surgical
    ("Q", 10021, 69990, "Surgical procedures — congenital repair"),
    ("Q", 99201, 99215, "Evaluation and management"),
    ("Q", 99281, 99285, "Emergency department visit"),
    ("Q", 70010, 76499, "Diagnostic radiology"),
    ("Q", 76801, 76828, "Obstetric ultrasound — fetal assessment"),
    ("Q", 80047, 89398, "Laboratory — genetic testing"),
    ("Q", 81161, 81479, "Genetic and genomic testing"),

    # R00-R99: Symptoms/Signs → Diagnostic evaluation
    ("R", 99201, 99215, "Evaluation and management"),
    ("R", 99281, 99285, "Emergency department visit"),
    ("R", 80047, 89398, "Pathology and laboratory testing"),
    ("R", 70010, 76499, "Diagnostic radiology"),
    ("R", 76506, 76999, "Diagnostic ultrasound"),
    ("R", 78000, 79999, "Nuclear medicine imaging"),
    ("R", 93000, 93018, "Electrocardiogram"),
    ("R", 94010, 94799, "Pulmonary function testing"),
    ("R", 95812, 95827, "Sleep testing"),
    ("R", 95965, 95967, "Evoked potential testing"),

    # S00-T88: Injury/Poisoning → Surgical, ED, trauma
    ("S", 10021, 69990, "Surgical procedures — trauma"),
    ("S", 12001, 13160, "Wound repair"),
    ("S", 20000, 29999, "Musculoskeletal trauma procedures"),
    ("S", 30000, 32999, "Respiratory trauma procedures"),
    ("S", 33010, 37799, "Cardiovascular trauma procedures"),
    ("S", 40490, 49999, "Digestive trauma procedures"),
    ("S", 50010, 53899, "Urinary trauma procedures"),
    ("S", 61000, 64999, "Neurological trauma procedures"),
    ("S", 65091, 68899, "Ocular trauma procedures"),
    ("S", 69000, 69990, "Otic trauma procedures"),
    ("S", 70010, 76499, "Diagnostic radiology — trauma imaging"),
    ("S", 80047, 89398, "Laboratory — toxicology"),
    ("S", 80300, 80377, "Drug testing"),
    ("S", 82000, 82024, "Toxicology chemistry"),
    ("S", 90001, 90080, "Burn treatment"),
    ("S", 96360, 96549, "IV therapy and infusion"),
    ("S", 99201, 99215, "Evaluation and management"),
    ("S", 99281, 99285, "Emergency department visit"),
    ("S", 99170, 99173, "Anoscopy and visual function"),
    ("T", 10021, 69990, "Surgical procedures — trauma"),
    ("T", 12001, 13160, "Wound repair"),
    ("T", 20000, 29999, "Musculoskeletal trauma procedures"),
    ("T", 80047, 89398, "Laboratory — toxicology"),
    ("T", 80300, 80377, "Drug testing"),
    ("T", 99201, 99215, "Evaluation and management"),
    ("T", 99281, 99285, "Emergency department visit"),

    # Z00-Z99: Health status/encounter → Preventive, admin
    ("Z", 99201, 99215, "Evaluation and management"),
    ("Z", 99281, 99285, "Emergency department visit"),
    ("Z", 99381, 99429, "Preventive medicine services"),
    ("Z", 99401, 99412, "Preventive counseling"),
    ("Z", 99450, 99456, "Life/disability insurance exam"),
    ("Z", 99460, 99469, "Newborn care"),
    ("Z", 99477, 99486, "Neonatal critical care"),
    ("Z", 80047, 89398, "Laboratory — screening"),
    ("Z", 90625, 90759, "Immunization administration"),
    ("Z", 77059, 77067, "Screening mammography"),
    ("Z", 77072, 77081, "Bone density screening"),
    ("Z", 82270, 82274, "Colorectal screening"),
    ("Z", 82947, 82985, "Diabetes screening"),
    ("Z", 84153, 84154, "PSA screening"),
    ("Z", 86190, 86190, "Cystatin C testing"),
    ("Z", 90630, 90749, "Vaccine products"),
    ("Z", 90460, 90461, "Immunization counseling"),
    ("Z", 90471, 90484, "Immunization administration"),

    # U00-U85: Special purposes
    ("U", 99201, 99215, "Evaluation and management"),
    ("U", 80047, 89398, "Laboratory testing"),
    ("U", 90625, 90759, "Immunization administration"),
    ("U", 96360, 96549, "Therapeutic infusion"),
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
    if icd_code is not None:
        icd_code = str(icd_code)
    if cpt_code_str is not None:
        cpt_code_str = str(cpt_code_str)

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

    # Try two-character prefix first (e.g. "H6" for ear disorders), fall back to single
    icd_prefix2 = icd_code[:2].upper() if len(icd_code) >= 2 else ""
    matched = []
    for rule_prefix, cpt_low, cpt_high, desc in _VALIDATION_RULES:
        prefix_matched = (rule_prefix == icd_prefix2) or (rule_prefix == icd_prefix)
        low_num = _parse_cpt_code(cpt_low) if isinstance(cpt_low, str) else cpt_low
        high_num = _parse_cpt_code(cpt_high) if isinstance(cpt_high, str) else cpt_high
        if prefix_matched and low_num <= cpt_num <= high_num:
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
