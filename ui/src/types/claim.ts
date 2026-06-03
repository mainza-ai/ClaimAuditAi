export interface HeldClaim {
  id: string;
  patientId: string;
  patientName?: string;
  providerId: string;
  cptCode: string;
  icdCode: string;
  totalAmount: number;
  submittedAt: string;
  lastModified: string;
  riskScore: number;
  riskLevel: 'critical' | 'high' | 'medium';
  escalated?: 0 | 1;
}

export interface AuditTierResult {
  tier: 1 | 2 | 3;
  label: string;
  score: number;
  threshold?: number;
  flags: string[];
  summary: string;
}

export interface ClaimDetail extends HeldClaim {
  disposition: string;
  tierResults: AuditTierResult[];
  taskId: string;
  communicationRequestId: string;
  linkedClinicalNotes: string[];
}

export interface SystemStats {
  held: number;
  approvedToday: number;
  interceptedTotal: number;
  totalValueHeld?: number;
  modelStatus: 'healthy' | 'degraded' | 'offline';
  leakageRate?: number;
  riskDistribution?: { level: string; count: number }[];
  tierDistribution?: { tier: string; count: number }[];
  dailyInterceptedCounts?: { date: string; count: number }[];
}

export interface TrendDay {
day: string;
processed: number;
held: number;
approved: number;
leakagePrevented: number;
}

export interface LedgerEntry {
id: string;
claimId: string;
patientId: string;
providerId: string;
  action: 'approved' | 'escalated' | 'rejected';
authorizedBy: string;
timestamp: string;
reason: string;
amount: number;
}