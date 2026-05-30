import clsx from 'clsx';
import type { HeldClaim } from '../../types/claim';

const LEVEL_STYLES = {
  critical: 'bg-red-600/20 text-red-400 border-red-700',
  high:     'bg-orange-600/20 text-orange-400 border-orange-700',
  medium:   'bg-yellow-600/20 text-yellow-400 border-yellow-700',
};

export function RiskBadge({
  level,
  score,
}: {
  level: HeldClaim['riskLevel'];
  score: number;
}) {
  return (
    <span
      className={clsx(
        'inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md border text-xs font-semibold font-mono uppercase tracking-wide',
        LEVEL_STYLES[level]
      )}
    >
      {level} · {score.toFixed(2)}
    </span>
  );
}