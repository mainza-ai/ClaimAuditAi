import type { AuditTierResult } from '../../types/claim';
import { ChevronDown, ChevronUp } from 'lucide-react';
import { useState } from 'react';
import clsx from 'clsx';

const TIER_COLORS = {
  1: 'border-blue-700/50 bg-blue-950/20 hover:bg-blue-950/30',
  2: 'border-amber-700/50 bg-amber-950/20 hover:bg-amber-950/30',
  3: 'border-red-700/50 bg-red-950/20 hover:bg-red-950/30',
};

const TIER_LABEL_COLORS = {
  1: 'text-blue-400',
  2: 'text-amber-400',
  3: 'text-red-400',
};

export function TierPanel({ result }: { result: AuditTierResult }) {
  const [expanded, setExpanded] = useState(true);

  return (
    <div className={clsx('border rounded-lg overflow-hidden transition-all', TIER_COLORS[result.tier])}>
      <button
        onClick={() => setExpanded((e) => !e)}
        className="w-full flex items-center justify-between px-4 py-3 text-left focus:outline-none"
      >
        <div className="flex items-center gap-3">
          <span className={clsx('text-xs font-bold font-mono tracking-wider', TIER_LABEL_COLORS[result.tier])}>
            TIER {result.tier}
          </span>
          <span className="text-sm font-semibold text-gray-200">{result.label}</span>
        </div>
        <div className="flex items-center gap-3">
          {result.score > 0 && (
            <span className="text-xs text-gray-400 font-mono">
              score: {result.score.toFixed(4)}
              {result.threshold ? ` / threshold: ${result.threshold.toFixed(4)}` : ''}
            </span>
          )}
          {expanded ? (
            <ChevronUp size={14} className="text-gray-500" />
          ) : (
            <ChevronDown size={14} className="text-gray-500" />
          )}
        </div>
      </button>

      {expanded && (
        <div className="px-4 pb-4 space-y-2 border-t border-gray-800/20 pt-3">
          <p className="text-sm text-gray-300 leading-relaxed">{result.summary}</p>
          {result.flags.length > 0 && (
            <ul className="space-y-1 mt-2">
              {result.flags.map((flag, i) => (
                <li key={i} className="flex items-start gap-2 text-sm text-gray-400">
                  <span className="text-red-500 mt-1 shrink-0">•</span>
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