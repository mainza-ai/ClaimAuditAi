import type { HeldClaim } from '../../types/claim';

const LEVEL_STYLES: Record<string, { color: string; backgroundColor: string; borderColor: string }> = {
  critical: {
    color: 'var(--color-danger)',
    backgroundColor: 'var(--color-danger-bg)',
    borderColor: 'var(--color-danger-border)',
  },
  high: {
    color: 'var(--color-warning)',
    backgroundColor: 'var(--color-warning-bg)',
    borderColor: 'var(--color-warning-border)',
  },
  medium: {
    color: 'var(--color-success)',
    backgroundColor: 'var(--color-success-bg)',
    borderColor: 'var(--color-success-border)',
  },
  low: { color: 'var(--text-tertiary)', backgroundColor: 'var(--bg-card)', borderColor: 'var(--border-default)' },
};

export function RiskBadge({ level, score }: { level: HeldClaim['riskLevel'] | 'low'; score: number }) {
  const styles = LEVEL_STYLES[level] || LEVEL_STYLES.low;

  return (
    <span
      className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md border text-xs font-semibold font-mono uppercase tracking-wide"
      style={{
        color: styles.color,
        backgroundColor: styles.backgroundColor,
        borderColor: styles.borderColor,
      }}
    >
      {level} · {score.toFixed(2)}
    </span>
  );
}
