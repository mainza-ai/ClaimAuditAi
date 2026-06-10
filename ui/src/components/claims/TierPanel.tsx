import type { AuditTierResult } from '../../types/claim';
import { ChevronDown, ChevronUp } from 'lucide-react';
import { useState } from 'react';
import ReactMarkdown from 'react-markdown';

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

  // Filter out flags that are duplicate or match the summary text
  const uniqueFlags = (result.flags || []).filter(
    (flag) => flag && flag.trim() !== '' && flag.trim().toLowerCase() !== (result.summary || '').trim().toLowerCase()
  );

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
          <span className="text-sm font-semibold" style={{ color: 'var(--text-primary)' }}>
            {result.label}
          </span>
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
        <div className="px-4 pb-4 space-y-2 border-t pt-3" style={{ borderColor: 'var(--border-default)' }}>
          <div className="text-sm leading-relaxed tier-panel-markdown" style={{ color: 'var(--text-primary)' }}>
            <ReactMarkdown>{result.summary || ''}</ReactMarkdown>
          </div>
          {uniqueFlags.length > 0 && (
            <ul className="space-y-1 mt-2">
              {uniqueFlags.map((flag, i) => (
                <li key={i} className="flex items-start gap-2 text-sm" style={{ color: 'var(--text-secondary)' }}>
                  <span className="mt-1 shrink-0" style={{ color: 'var(--color-danger)' }}>
                    •
                  </span>
                  <div className="tier-panel-markdown flex-1" style={{ color: 'var(--text-secondary)' }}>
                    <ReactMarkdown>{flag}</ReactMarkdown>
                  </div>
                </li>
              ))}
            </ul>
          )}
          {result.citations && result.citations.length > 0 && (
            <div className="mt-3 pt-3 border-t flex flex-wrap gap-2 items-center" style={{ borderColor: 'var(--border-default)' }}>
              <span className="text-xs font-bold uppercase tracking-wider mr-1" style={{ color: 'var(--text-tertiary)' }}>
                Evidence:
              </span>
              {result.citations.map((citation, i) => (
                <span
                  key={i}
                  className="px-2 py-0.5 rounded text-xs font-mono border hover:scale-105 transition-transform cursor-default flex items-center gap-1.5"
                  style={{
                    backgroundColor: 'var(--bg-card)',
                    borderColor: 'var(--border-default)',
                    color: 'var(--text-secondary)',
                    boxShadow: '0 1px 2px rgba(0, 0, 0, 0.05)'
                  }}
                >
                  <span className="w-1.5 h-1.5 rounded-full" style={{ backgroundColor: TIER_LABEL_COLORS[result.tier] }} />
                  {citation}
                </span>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
