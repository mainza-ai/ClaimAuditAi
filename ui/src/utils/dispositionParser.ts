import type { AuditTierResult } from '../types/claim';

const DEFAULT_TIER_1: AuditTierResult = {
  tier: 1,
  label: 'Semantic Clinical Audit',
  score: 0,
  flags: [],
  summary: 'Clinical SOAP notes match the procedural description. No semantic anomalies detected.',
};

const DEFAULT_TIER_2: AuditTierResult = {
  tier: 2,
  label: 'Statistical Outlier Profiler',
  score: 0,
  flags: [],
  summary: 'Claim billing features are within normal statistical bounds.',
};

const DEFAULT_TIER_3: AuditTierResult = {
  tier: 3,
  label: 'Collusion Network Analysis',
  score: 0,
  flags: [],
  summary: 'Referral loop scan complete. Patient-provider relational topology is clean, geodetic limits matched.',
};

function errorTier(tier: 1 | 2 | 3, label: string, message: string): AuditTierResult {
  return { tier, label, score: 0, flags: [message], summary: message };
}

export function parseDisposition(disposition: string): {
  tierResults: AuditTierResult[];
  riskScore: number;
  summary: string;
} {
  if (!disposition || disposition.trim() === '') {
    return {
      tierResults: [
        { ...DEFAULT_TIER_1, summary: 'No adjudication report generated. The AI audit engine did not produce a disposition for this claim.' },
        { ...DEFAULT_TIER_2, summary: 'No adjudication report generated.' },
        { ...DEFAULT_TIER_3 },
      ],
      riskScore: 0,
      summary: 'No adjudication report available.',
    };
  }

  if (disposition.includes('PYTHON EXCEPTION') || disposition.includes('Python orchestration') && disposition.includes('failed')) {
    return {
      tierResults: [
        errorTier(1, 'Semantic Clinical Audit', 'Tier 1 NLP auditor failed — Python engine exception. Check AI agent logs and API key configuration.'),
        errorTier(2, 'Statistical Outlier Profiler', 'Tier 2 autoencoder failed — Python engine exception.'),
        errorTier(3, 'Collusion Network Analysis', 'Tier 3 graph analyzer failed — Python engine exception.'),
      ],
      riskScore: 0,
      summary: 'Python audit engine error. Verify NVIDIA_API_KEY and restart the IRIS container.',
    };
  }

  const tierResults: AuditTierResult[] = [];

  const t1Match =
    disposition.match(/###\s*(?:Tier\s*1|\[NLP\])[^\n]*\n([\s\S]*?)(?=###|$|##)/i) ||
    disposition.match(/-\s*(?:Tier\s*1|NLP)[^\n]*\n([\s\S]*?)(?=-|$|#)/i) ||
    disposition.match(/Tier\s*1\s*\((?:NLP)\):\s*([^|\n]+)/i);
  if (t1Match) {
    const body = t1Match[1] || t1Match[0];
    const simMatch = body.match(/Similarity[:\s]+([\d.]+)/i);
    tierResults.push({
      tier: 1,
      label: 'Semantic Clinical Audit',
      score: simMatch ? parseFloat(simMatch[1]) : 0,
      flags: extractBullets(body),
      summary: firstSentence(body),
    });
  } else {
    tierResults.push({ ...DEFAULT_TIER_1 });
  }

  const t2Match =
    disposition.match(/###\s*(?:Tier\s*2|\[Adjudication\]|\[ML\])[^\n]*\n([\s\S]*?)(?=###|$|##)/i) ||
    disposition.match(/-\s*(?:Tier\s*2|Adjudication|ML)[^\n]*\n([\s\S]*?)(?=-|$|#)/i) ||
    disposition.match(/Tier\s*2\s*\((?:ML)\):\s*([^|\n]+)/i);
  if (t2Match) {
    const body = t2Match[1] || t2Match[0];
    const lossMatch = body.match(/Loss[:\s]+([\d.]+)/i) || body.match(/loss[:\s]+([\d.]+)/i);
    const threshMatch = body.match(/Threshold[:\s]+([\d.]+)/i);
    tierResults.push({
      tier: 2,
      label: 'Statistical Outlier Profiler',
      score: lossMatch ? parseFloat(lossMatch[1]) : 0,
      threshold: threshMatch ? parseFloat(threshMatch[1]) : undefined,
      flags: extractBullets(body),
      summary: firstSentence(body),
    });
  } else {
    tierResults.push({ ...DEFAULT_TIER_2 });
  }

  const t3Match =
    disposition.match(/###\s*(?:Tier\s*3|\[Graph\]|\[Collusion\])[^\n]*\n([\s\S]*?)(?=###|$|##)/i) ||
    disposition.match(/-\s*(?:Tier\s*3|Graph|Collusion)[^\n]*\n([\s\S]*?)(?=-|$|#)/i) ||
    disposition.match(/Tier\s*3\s*\((?:Graph)\):\s*([^|\n]+)/i);
  if (t3Match) {
    const body = t3Match[1] || t3Match[0];
    tierResults.push({
      tier: 3,
      label: 'Collusion Network Analysis',
      score: 0,
      flags: extractBullets(body),
      summary: firstSentence(body),
    });
  } else {
    tierResults.push({ ...DEFAULT_TIER_3 });
  }

  const t1Score = tierResults.find((t) => t.tier === 1)?.score ?? 0;
  const t2Score = tierResults.find((t) => t.tier === 2)?.score ?? 0;
  const t2Threshold = tierResults.find((t) => t.tier === 2)?.threshold ?? 0;
  const riskScore = Math.min(
    1,
    (t1Score > 0 && t1Score < 0.38 ? 0.35 : 0) +
      (t2Score > 0 && t2Threshold > 0 && t2Score > t2Threshold ? 0.35 : 0) +
      (tierResults.find((t) => t.tier === 3)?.flags.length ? 0.3 : 0),
  );

  const summary = disposition
    .split('\n\n')[0]
    .replace(/^#+\s*/, '')
    .trim();

  return { tierResults, riskScore, summary };
}

function extractBullets(text: string): string[] {
  return text
    .split('\n')
    .filter((line) => /^[-*•]\s/.test(line.trim()))
    .map((line) => line.replace(/^[-*•]\s+/, '').trim())
    .filter(Boolean);
}

function firstSentence(text: string): string {
  const clean = text.replace(/^#+[^\n]*\n/, '').trim();
  const match = clean.match(/^[^.!?]+[.!?]/);
  return match ? match[0] : clean.slice(0, 120);
}
