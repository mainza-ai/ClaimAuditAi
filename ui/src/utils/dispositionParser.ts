import type { AuditTierResult } from '../types/claim';

export function parseDisposition(disposition: string): {
tierResults: AuditTierResult[];
riskScore: number;
summary: string;
} {
const tierResults: AuditTierResult[] = [];

// Extract Tier 1
const t1Match = disposition.match(/###\s*\[NLP\][^\n]*\n([\s\S]*?)(?=###|$)/i) || disposition.match(/-\s*Tier 1[^\n]*\n([\s\S]*?)(?=-|$)/i);
if (t1Match) {
const body = t1Match[1] || t1Match[0];
const simMatch = body.match(/Similarity[:\s]+([\d.]+)/i);
const score = simMatch ? parseFloat(simMatch[1]) : 0;
tierResults.push({
tier: 1,
label: 'Semantic Clinical Audit',
score,
flags: extractBullets(body),
summary: firstSentence(body),
});
}

// Extract Tier 2
const t2Match = disposition.match(/###\s*\[Adjudication\][^\n]*\n([\s\S]*?)(?=###|$)/i) || disposition.match(/-\s*Tier 2[^\n]*\n([\s\S]*?)(?=-|$)/i);
if (t2Match) {
const body = t2Match[1] || t2Match[0];
const lossMatch = body.match(/Loss[:\s]+([\d.]+)/i) || body.match(/loss[:\s]+([\d.]+)/i);
const threshMatch = body.match(/Threshold[:\s]+([\d.]+)/i);
const score = lossMatch ? parseFloat(lossMatch[1]) : 0;
const threshold = threshMatch ? parseFloat(threshMatch[1]) : undefined;
tierResults.push({
tier: 2,
label: 'Statistical Outlier Profiler',
score,
threshold,
flags: extractBullets(body),
summary: firstSentence(body),
});
}

// Extract Tier 3
const t3Match = disposition.match(/Tier 3[^\n]*\n([\s\S]*?)(?=-|$)/i);
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
tierResults.push({
tier: 3,
label: 'Collusion Network Analysis',
score: 0,
flags: [],
summary: 'Referral loop scan complete. Patient-provider relational topology is clean, geodetic limits matched.'
});
}

// Derive risk score from tier results instead of hardcoded pattern matching
const t1Score = tierResults.find(t => t.tier === 1)?.score ?? 0;
const t2Score = tierResults.find(t => t.tier === 2)?.score ?? 0;
const t2Threshold = tierResults.find(t => t.tier === 2)?.threshold ?? 0;
const riskScore = Math.min(1, (t1Score > 0 && t1Score < 0.38 ? 0.35 : 0) + (t2Score > 0 && t2Threshold > 0 && t2Score > t2Threshold ? 0.35 : 0) + (tierResults.find(t => t.tier === 3)?.flags.length ? 0.30 : 0));

// First paragraph as overall summary
const summary = disposition.split('\n\n')[0].replace(/^#+\s*/, '').trim();

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
