export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
  timestamp: string;
}

export interface ClaimContext {
  claimId: string;
  patientId: string;
  cptCode: string;
  riskScore: number;
  dispositionSummary: string;
  tier1Summary: string;
  tier2Loss: number;
  tier2Threshold: number;
  tier3Flags: string[];
}