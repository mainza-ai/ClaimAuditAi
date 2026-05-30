import type { AuditTierResult } from '../../types/claim';
import { ChevronDown, ChevronUp } from 'lucide-react';
import { useState } from 'react';

const TIER_STYLES: Record<number, { borderColor: string; backgroundColor: string }> = {
  1: { borderColor: 'var(--border-focus)', backgroundColor: 'var(--accent-subtle)' },
  2: { borderColor: 'var(--color-warning-border)', backgroundColor: 'var(--color-warning-bg)' },
  3: { borderColor: 'var(--color-danger-border)', backgroundColor: 'var(--color-danger-bg)' },
};

const TIER_LABEL_COLORS: Record<number, string> = {
  1: 'var(--accent-primary)',
  2: 'var(--color-warning)',
  3: 'var(--color-danger)',
};

export function TierPanel({ result }: { result: AuditTierResult }) {
  const [expanded, setExpanded] = useState(true);

  const tierStyle = TIER_STYLES[result.tier];

  return (
    <div
      className="border rounded-lg overflow-hidden transition-all"
      style={{
        borderColor: tierStyle.borderColor,
        backgroundColor: tierStyle.backgroundColor,
      }}
    >
      <button
        onClick={() => setExpanded((e) => !e)}
        className="w-full flex items-center justify-between px-4 py-3 text-left focus:outline-none"
      >
        <div className="flex items-center gap-3">
          <span
            className="text-xs font-bold font-mono tracking-wider"
            style={{ color: TIER_LABEL_COLORS[result.tier] }}
          >
            TIER {result.tier}
          </span>
          <span className="text-sm font-semibold" style={{ color: 'var(--text-primary)' }}>{result.label}</span>
        </div>
        <div className="flex items-center gap-3">
          {result.score > 0 && (
            <span className="text-xs font-mono" style={{ color: 'var(--text-secondary)' }}>
              score: {result.score.toFixed(4)}
              {result.threshold ? ` / threshold: ${result.threshold.toFixed(4)}` : ''}
            </span>
          )}
          {expanded ? (
            <ChevronUp size={14} style={{ color: 'var(--text-tertiary)' }} />
          ) : (
            <ChevronDown size={14} style={{ color: 'var(--text-tertiary)' }} />
          )}
        </div>
      </button>

      {expanded && (
        <div
          className="px-4 pb-4 space-y-2 border-t pt-3"
          style={{ borderColor: 'var(--border-default)' }}
        >
          <p className="text-sm leading-relaxed" style={{ color: 'var(--text-primary)' }}>{result.summary}</p>
          {result.flags.length > 0 && (
            <ul className="space-y-1 mt-2">
              {result.flags.map((flag, i) => (
                <li key={i} className="flex items-start gap-2 text-sm" style={{ color: 'var(--text-secondary)' }}>
                  <span className="mt-1 shrink-0" style={{ color: 'var(--color-danger)' }}>•</span>
                  <span>{flag}</span>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </div>
  );
}
