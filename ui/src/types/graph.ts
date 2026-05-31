export interface GraphInsight {
  type: string;
  severity: 'critical' | 'high' | 'medium';
  message: string;
  claimIds?: string[];
  date?: string;
  patient?: string;
  providerId?: string;
}

export interface GraphData {
  nodes: { data: { id: string; label: string; type: string; address?: string } }[];
  edges: { data: { id: string; source: string; target: string; label: string; amount?: number; date?: string } }[];
  insights: GraphInsight[];
  nodeCount: number;
  edgeCount: number;
  insightCount: number;
}
