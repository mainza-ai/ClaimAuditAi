import type { HeldClaim, ClaimDetail } from '../types/claim';

export const SIMULATED_CLAIMS: HeldClaim[] = [
  {
    id: "CLM-9382-A",
    patientId: "PAT-claimaudit-01",
    providerId: "NPI-99482103",
    cptCode: "CPT 99291: Critical care, evaluation and management of the unstable critically ill or critically injured patient; first 30-74 minutes.",
    icdCode: "ICD-10 I10: Essential (primary) hypertension",
    totalAmount: 2500,
    submittedAt: new Date(Date.now() - 3600000 * 2).toISOString(),
    lastModified: new Date(Date.now() - 3600000 * 0.5).toISOString(),
    riskScore: 0.94,
    riskLevel: "critical"
  },
  {
    id: "CLM-8812-B",
    patientId: "PAT-claimaudit-02",
    providerId: "NPI-88392182",
    cptCode: "CPT 33510: Coronary artery bypass, vein only; single coronary venous graft.",
    icdCode: "ICD-10 J44.9: Chronic obstructive pulmonary disease, unspecified",
    totalAmount: 14850,
    submittedAt: new Date(Date.now() - 3600000 * 12).toISOString(),
    lastModified: new Date(Date.now() - 3600000 * 2).toISOString(),
    riskScore: 0.88,
    riskLevel: "high"
  },
  {
    id: "CLM-1102-C",
    patientId: "PAT-claimaudit-03",
    providerId: "NPI-11029381",
    cptCode: "CPT 99214: Office or other outpatient visit for the evaluation and management of an established patient, moderate level of decision making.",
    icdCode: "ICD-10 I25.10: Atherosclerotic heart disease of native coronary artery without angina pectoris",
    totalAmount: 850,
    submittedAt: new Date(Date.now() - 3600000 * 24).toISOString(),
    lastModified: new Date(Date.now() - 3600000 * 18).toISOString(),
    riskScore: 0.45,
    riskLevel: "medium"
  },
  {
    id: "CLM-4712-D",
    patientId: "PAT-claimaudit-04",
    providerId: "NPI-38192831",
    cptCode: "CPT 99292: Critical care, evaluation and management of the unstable critically ill or critically injured patient; each additional 30 minutes.",
    icdCode: "ICD-10 E11.9: Type 2 diabetes mellitus without complications",
    totalAmount: 24500,
    submittedAt: new Date(Date.now() - 3600000 * 36).toISOString(),
    lastModified: new Date(Date.now() - 3600000 * 26).toISOString(),
    riskScore: 0.91,
    riskLevel: "critical"
  },
  {
    id: "CLM-9938-E",
    patientId: "PAT-claimaudit-05",
    providerId: "NPI-99482103",
    cptCode: "CPT 93000: Electrocardiogram, routine ECG with at least 12 leads; with interpretation and report.",
    icdCode: "ICD-10 R07.9: Chest pain, unspecified",
    totalAmount: 1250,
    submittedAt: new Date(Date.now() - 3600000 * 48).toISOString(),
    lastModified: new Date(Date.now() - 3600000 * 32).toISOString(),
    riskScore: 0.58,
    riskLevel: "medium"
  },
  {
    id: "CLM-2204-F",
    patientId: "PAT-claimaudit-06",
    providerId: "NPI-47392810",
    cptCode: "CPT 32551: Tube thoracostomy, includes water seal (eg, for abscess, hemothorax, empyema), with or without pleural procedure.",
    icdCode: "ICD-10 S27.0XXA: Traumatic pneumothorax, initial encounter",
    totalAmount: 6200,
    submittedAt: new Date(Date.now() - 3600000 * 60).toISOString(),
    lastModified: new Date(Date.now() - 3600000 * 45).toISOString(),
    riskScore: 0.72,
    riskLevel: "high"
  },
  {
    id: "CLM-8830-G",
    patientId: "PAT-claimaudit-07",
    providerId: "NPI-22948301",
    cptCode: "CPT 94010: Spirometry, including graphic record, total and timed vital capacity, expiratory flow rate measurement(s), with or without maximal voluntary ventilation.",
    icdCode: "ICD-10 J45.909: Unspecified asthma, uncomplicated",
    totalAmount: 3600,
    submittedAt: new Date(Date.now() - 3600000 * 72).toISOString(),
    lastModified: new Date(Date.now() - 3600000 * 50).toISOString(),
    riskScore: 0.65,
    riskLevel: "high"
  },
  {
    id: "CLM-1039-H",
    patientId: "PAT-claimaudit-08",
    providerId: "NPI-88392182",
    cptCode: "CPT 99205: Office or other outpatient visit for the evaluation and management of a new patient, high level of decision making.",
    icdCode: "ICD-10 M54.50: Low back pain, unspecified",
    totalAmount: 480,
    submittedAt: new Date(Date.now() - 3600000 * 96).toISOString(),
    lastModified: new Date(Date.now() - 3600000 * 60).toISOString(),
    riskScore: 0.38,
    riskLevel: "medium"
  }
];

export const SIMULATED_DETAILS: Record<string, ClaimDetail> = {
  "CLM-9382-A": {
    id: "CLM-9382-A",
    patientId: "PAT-claimaudit-01",
    providerId: "NPI-99482103",
    cptCode: "CPT 99291: Critical care, evaluation and management of the unstable critically ill or critically injured patient; first 30-74 minutes.",
    icdCode: "ICD-10 I10: Essential (primary) hypertension",
    totalAmount: 2500,
    submittedAt: new Date(Date.now() - 3600000 * 2).toISOString(),
    lastModified: new Date(Date.now() - 3600000 * 0.5).toISOString(),
    riskScore: 0.94,
    riskLevel: "critical",
    disposition: `# [WARNING] Pre-Payment Audit Adjudication HOLD Notification
This claim has been pended for manual audit review due to extreme clinical-financial discrepancies.

### [Tier 1] Semantic Clinical Auditing:
- **Flagged Mismatch**: Billed procedure is for CPT 99291 (Critical Care, E&M of unstable critically ill patients), but patient record progress note describes a simple hypertension follow-up physical checkup.
- **Vector Cosine Proximity**: similarity is 0.22, far below standard safety threshold of 0.38. Upcoding is highly suspected.

### [Tier 2] Statistical Outlier Profiling:
- **Anomaly Score**: Reconstruction loss is 179.95 (Threshold 0.842).
- **Outlier Indices**: The pricing distribution and CPT billing frequency per specialty is in the 98th percentile outlier bounds.

### [Tier 3] Collusion Network Mapping:
- **Centrality Loop**: Patient address matches the physical geolocation coordinates of the referring clinic (shared billing IP loop). Cycle anomaly verified.`,
    tierResults: [
      { tier: 1, label: "Semantic Clinical Auditing", score: 0.22, threshold: 0.38, flags: ["Clinical Mismatch", "Upcoding"], summary: "Billed procedure CPT 99291 (Critical Care) does not align with patient physical checkup progress notes." },
      { tier: 2, label: "Statistical Outlier Profiling", score: 179.95, threshold: 0.84, flags: ["Outlier Volume", "Pricing Deviation"], summary: "Billing features are in the 98th percentile outlier bounds for this specialty." },
      { tier: 3, label: "Collusion Network Mapping", score: 0.92, flags: ["IP Loop", "Shared Coordinates"], summary: "Patient address geolocates to same physical coordinates as referring clinic." }
    ],
    taskId: "TASK-781",
    communicationRequestId: "COMM-290",
    linkedClinicalNotes: ["Patient visited today for a routine yearly physical checkup. Vital signs are normal. Patient has no acute complaints. Blood pressure is slightly elevated at 135/85; advised to continue primary hypertension medications."]
  },
  "CLM-8812-B": {
    id: "CLM-8812-B",
    patientId: "PAT-claimaudit-02",
    providerId: "NPI-88392182",
    cptCode: "CPT 33510: Coronary artery bypass, vein only; single coronary venous graft.",
    icdCode: "ICD-10 J44.9: Chronic obstructive pulmonary disease, unspecified",
    totalAmount: 14850,
    submittedAt: new Date(Date.now() - 3600000 * 12).toISOString(),
    lastModified: new Date(Date.now() - 3600000 * 2).toISOString(),
    riskScore: 0.88,
    riskLevel: "high",
    disposition: `# [WARNING] Pre-Payment Audit Adjudication HOLD Notification
This claim has been pended for manual audit review due to complex upcoding triggers.

### [Tier 1] Semantic Clinical Auditing:
- **Flagged Mismatch**: Billed procedure is for CPT 33510 (Coronary artery bypass graft), but patient record progress note describes a chronic obstructive pulmonary disease (COPD) inhaler management follow-up.
- **Vector Cosine Proximity**: similarity is 0.15, far below standard safety threshold of 0.38. Severe billing abuse suspected.

### [Tier 2] Statistical Outlier Profiling:
- **Anomaly Score**: Reconstruction loss is 245.88 (Threshold 0.842).
- **Outlier Indices**: Cardiac surgery codes billed from an outpatient pulmonary specialty clinic are a critical structural outlier.`,
    tierResults: [
      { tier: 1, label: "Semantic Clinical Auditing", score: 0.15, threshold: 0.38, flags: ["Critical Surgical Mismatch"], summary: "Pulmonary clinic progress note describes basic COPD management; billed for invasive coronary artery bypass surgery." },
      { tier: 2, label: "Statistical Outlier Profiling", score: 245.88, threshold: 0.84, flags: ["Specialty Code Mismatch"], summary: "Billed cardiac surgery code from a registered pulmonologist clinic is a structural outlier." }
    ],
    taskId: "TASK-891",
    communicationRequestId: "COMM-301",
    linkedClinicalNotes: ["Patient arrived for follow-up COPD inhaler adjustment. Evaluated lung capacity; patient has minor shortness of breath on exertion. Prescribed renewal of albuterol inhaler. Overall clinical status stable."]
  },
  "CLM-1102-C": {
    id: "CLM-1102-C",
    patientId: "PAT-claimaudit-03",
    providerId: "NPI-11029381",
    cptCode: "CPT 99214: Office or other outpatient visit for the evaluation and management of an established patient, moderate level of decision making.",
    icdCode: "ICD-10 I25.10: Atherosclerotic heart disease of native coronary artery without angina pectoris",
    totalAmount: 850,
    submittedAt: new Date(Date.now() - 3600000 * 24).toISOString(),
    lastModified: new Date(Date.now() - 3600000 * 18).toISOString(),
    riskScore: 0.45,
    riskLevel: "medium",
    disposition: `# [APPROVED] Payment Integrity Verification PASSED
This claim has been processed, audited, and cleared for disbursal.

### [Tier 1] Semantic Clinical Auditing:
- **Aligned Match**: Billed procedure is for CPT 99214 (Established Outpatient E&M, Moderate), and progress notes confirm a complex atherosclerotic heart disease coronary follow-up, reviewing laboratory panels and adjusting beta blockers.
- **Vector Cosine Proximity**: similarity is 0.72, well above standard safety threshold of 0.38.

### [Tier 2] Statistical Outlier Profiling:
- **Anomaly Score**: Reconstruction loss is 0.35 (Threshold 0.842). Fully within normal distribution bounds.`,
    tierResults: [
      { tier: 1, label: "Semantic Clinical Auditing", score: 0.72, threshold: 0.38, flags: ["Verified Clinical Support"], summary: "Progress notes confirm detailed coronary monitoring and medication adjustment supporting CPT 99214." },
      { tier: 2, label: "Statistical Outlier Profiling", score: 0.35, threshold: 0.84, flags: ["Normal Range"], summary: "Pricing and billing frequency are fully within regular baseline distributions." }
    ],
    taskId: "TASK-102",
    communicationRequestId: "COMM-112",
    linkedClinicalNotes: ["Established patient returns for management of atherosclerotic coronary artery disease. Reviewed recent lipid panel and adjusted carvedilol dosing. Patient denies active chest pain or shortness of breath. Plan: continue carvedilol, return in 3 months."]
  },
  "CLM-4712-D": {
    id: "CLM-4712-D",
    patientId: "PAT-claimaudit-04",
    providerId: "NPI-38192831",
    cptCode: "CPT 99292: Critical care, evaluation and management of the unstable critically ill or critically injured patient; each additional 30 minutes.",
    icdCode: "ICD-10 E11.9: Type 2 diabetes mellitus without complications",
    totalAmount: 24500,
    submittedAt: new Date(Date.now() - 3600000 * 36).toISOString(),
    lastModified: new Date(Date.now() - 3600000 * 26).toISOString(),
    riskScore: 0.91,
    riskLevel: "critical",
    disposition: `# [WARNING] Pre-Payment Audit Adjudication HOLD Notification
This claim has been pended for manual audit review due to suspicious multi-hour critical care billing.

### [Tier 1] Semantic Clinical Auditing:
- **Flagged Mismatch**: Billed CPT 99292 represents extended critical care services (over 74 minutes), but patient record progress note describes a routine Type 2 diabetes medication adjustment follow-up.
- **Vector Cosine Proximity**: similarity is 0.18 (Safety Threshold: 0.38).

### [Tier 2] Statistical Outlier Profiling:
- **Anomaly Score**: Reconstruction loss is 189.50 (Threshold 0.842). Extreme billing amount outlier.`,
    tierResults: [
      { tier: 1, label: "Semantic Clinical Auditing", score: 0.18, threshold: 0.38, flags: ["Extreme Upcoding"], summary: "Billed extended critical care time (CPT 99292) does not align with basic diabetes medication checkup notes." },
      { tier: 2, label: "Statistical Outlier Profiling", score: 189.50, threshold: 0.84, flags: ["Extravagant Pricing"], summary: "Billed amount of $24,500 is in the top 99th percentile statistical outlier bounds." }
    ],
    taskId: "TASK-471",
    communicationRequestId: "COMM-192",
    linkedClinicalNotes: ["Patient arrived for checkup of Type 2 diabetes. Checked A1C levels, which remain stable at 6.8. Adjusted metformin dosage to 500mg BID. Advised patient on strict dietary adherence. Return in 6 months."]
  },
  "CLM-9938-E": {
    id: "CLM-9938-E",
    patientId: "PAT-claimaudit-05",
    providerId: "NPI-99482103",
    cptCode: "CPT 93000: Electrocardiogram, routine ECG with at least 12 leads; with interpretation and report.",
    icdCode: "ICD-10 R07.9: Chest pain, unspecified",
    totalAmount: 1250,
    submittedAt: new Date(Date.now() - 3600000 * 48).toISOString(),
    lastModified: new Date(Date.now() - 3600000 * 32).toISOString(),
    riskScore: 0.58,
    riskLevel: "medium",
    disposition: `# [APPROVED] Payment Integrity Verification PASSED
This claim has been processed, audited, and cleared for disbursal.

### [Tier 1] Semantic Clinical Auditing:
- **Aligned Match**: Billed CPT 93000 (Electrocardiogram) is fully supported by the clinical notes confirming acute onset chest pain and immediate 12-lead ECG testing.
- **Vector Cosine Proximity**: similarity is 0.81 (Safety Threshold: 0.38).

### [Tier 2] Statistical Outlier Profiling:
- **Anomaly Score**: Reconstruction loss is 0.42 (Threshold 0.842). Fully within regular baseline limits.`,
    tierResults: [
      { tier: 1, label: "Semantic Clinical Auditing", score: 0.81, threshold: 0.38, flags: ["Verified Clinical Support"], summary: "Progress notes confirm immediate 12-lead ECG testing in response to acute chest pain." },
      { tier: 2, label: "Statistical Outlier Profiling", score: 0.42, threshold: 0.84, flags: ["Normal Range"], summary: "Pricing and billing frequency are fully within regular baseline distributions." }
    ],
    taskId: "TASK-993",
    communicationRequestId: "COMM-320",
    linkedClinicalNotes: ["Patient presented with acute onset crushing chest pain radiating to left shoulder. Placed patient on oxygen immediately. Performed 12-lead ECG which showed regular sinus rhythm without ST elevation. Transferred to emergency room for safety."]
  },
  "CLM-2204-F": {
    id: "CLM-2204-F",
    patientId: "PAT-claimaudit-06",
    providerId: "NPI-47392810",
    cptCode: "CPT 32551: Tube thoracostomy, includes water seal (eg, for abscess, hemothorax, empyema), with or without pleural procedure.",
    icdCode: "ICD-10 S27.0XXA: Traumatic pneumothorax, initial encounter",
    totalAmount: 6200,
    submittedAt: new Date(Date.now() - 3600000 * 60).toISOString(),
    lastModified: new Date(Date.now() - 3600000 * 45).toISOString(),
    riskScore: 0.72,
    riskLevel: "high",
    disposition: `# [WARNING] Pre-Payment Audit Adjudication HOLD Notification
This claim has been pended for manual audit review due to systemic network geolocational anomalies.

### [Tier 1] Semantic Clinical Auditing:
- **Aligned Match**: Billed CPT 32551 (Tube thoracostomy) matches the clinical progress notes confirming a traumatic pneumothorax thoracic chest tube insertion.
- **Vector Cosine Proximity**: similarity is 0.76 (Safety Threshold: 0.38).

### [Tier 2] Statistical Outlier Profiling:
- **Anomaly Score**: Reconstruction loss is 1.10. Normal limits.

### [Tier 3] Collusion Network Mapping:
- **Geographical Centrality Outlier**: The submitting clinic geolocates to a physical coordinate loop in Florida, while the referring provider and patient reside in California. Geo-temporal leaps detected.`,
    tierResults: [
      { tier: 1, label: "Semantic Clinical Auditing", score: 0.76, threshold: 0.38, flags: ["Clinical Support Validated"], summary: "Progress notes fully justify emergency chest tube insertion." },
      { tier: 3, label: "Collusion Network Mapping", score: 0.98, flags: ["Geo-Leap Anomaly", "Shell Clinic Suspicion"], summary: "Submitting clinic in Florida geolocates thousands of miles away from patient and referring doctor's residency." }
    ],
    taskId: "TASK-220",
    communicationRequestId: "COMM-450",
    linkedClinicalNotes: ["Patient arrived via EMS with traumatic pneumothorax after motor vehicle accident. Placed left-sided chest tube under sterile technique with water-seal drainage system. Placed on monitoring; lung re-expansion confirmed by chest X-ray."]
  },
  "CLM-8830-G": {
    id: "CLM-8830-G",
    patientId: "PAT-claimaudit-07",
    providerId: "NPI-22948301",
    cptCode: "CPT 94010: Spirometry, including graphic record, total and timed vital capacity, expiratory flow rate measurement(s), with or without maximal voluntary ventilation.",
    icdCode: "ICD-10 J45.909: Unspecified asthma, uncomplicated",
    totalAmount: 3600,
    submittedAt: new Date(Date.now() - 3600000 * 72).toISOString(),
    lastModified: new Date(Date.now() - 3600000 * 50).toISOString(),
    riskScore: 0.65,
    riskLevel: "high",
    disposition: `# [WARNING] Pre-Payment Audit Adjudication HOLD Notification
This claim has been pended for manual audit review due to extreme statistical frequency outlier flags.

### [Tier 1] Semantic Clinical Auditing:
- **Aligned Match**: Billed Spirometry (CPT 94010) matches standard asthma nebulizer documentation.
- **Vector Cosine Proximity**: similarity is 0.68.

### [Tier 2] Statistical Outlier Profiling:
- **Frequency Abuse**: Reconstruction loss is 92.40 (Threshold 0.842).
- **Outlier Indices**: The provider billed Spirometry tests 12 separate times for this patient in the last 30 days. Maximum permitted standard frequency is once per quarter. Billing abuse is highly suspected.`,
    tierResults: [
      { tier: 1, label: "Semantic Clinical Auditing", score: 0.68, threshold: 0.38, flags: ["Clinical Support Validated"], summary: "Spirometry testing is clinically appropriate for asthma monitoring." },
      { tier: 2, label: "Statistical Outlier Profiling", score: 92.40, threshold: 0.84, flags: ["Frequency Abuse Outlier"], summary: "Billed Spirometry tests 12 times in 30 days, representing extreme frequency over-utilization." }
    ],
    taskId: "TASK-883",
    communicationRequestId: "COMM-500",
    linkedClinicalNotes: ["Asthmatic patient presents with worsening wheezing. Administered albuterol nebulizer treatment. Performed spirometry to measure vital capacity and lung volume changes post-treatment. Lung function improved; discharged home."]
  },
  "CLM-1039-H": {
    id: "CLM-1039-H",
    patientId: "PAT-claimaudit-08",
    providerId: "NPI-88392182",
    cptCode: "CPT 99205: Office or other outpatient visit for the evaluation and management of a new patient, high level of decision making.",
    icdCode: "ICD-10 M54.50: Low back pain, unspecified",
    totalAmount: 480,
    submittedAt: new Date(Date.now() - 3600000 * 96).toISOString(),
    lastModified: new Date(Date.now() - 3600000 * 60).toISOString(),
    riskScore: 0.38,
    riskLevel: "medium",
    disposition: `# [APPROVED] Payment Integrity Verification PASSED
This claim has been processed, audited, and cleared for disbursal.

### [Tier 1] Semantic Clinical Auditing:
- **Aligned Match**: Billed Level 5 New Patient E&M (CPT 99205) is supported by progress notes detailing comprehensive orthopedic spinal evaluation, reflex checking, and referral for lumbar MRI.
- **Vector Cosine Proximity**: similarity is 0.64 (Safety Threshold: 0.38).

### [Tier 2] Statistical Outlier Profiling:
- **Anomaly Score**: Reconstruction loss is 0.51 (Threshold 0.842). Fully within regular baseline limits.`,
    tierResults: [
      { tier: 1, label: "Semantic Clinical Auditing", score: 0.64, threshold: 0.38, flags: ["Verified Clinical Support"], summary: "Progress notes confirm detailed new patient spinal assessment and MRI scheduling supporting CPT 99205." },
      { tier: 2, label: "Statistical Outlier Profiling", score: 0.51, threshold: 0.84, flags: ["Normal Range"], summary: "Pricing and billing frequency are fully within regular baseline distributions." }
    ],
    taskId: "TASK-103",
    communicationRequestId: "COMM-600",
    linkedClinicalNotes: ["New patient presents with severe unspecified low back pain radiating down left lower extremity. Conducted complete orthopedic lumbar assessment. Lower extremity reflexes 1+. Scheduling patient for diagnostic lumbar MRI and starting physical therapy."]
  }
};
