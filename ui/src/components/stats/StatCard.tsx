import type { LucideIcon } from 'lucide-react';
import clsx from 'clsx';

const ACCENT_STYLES = {
  red:   'text-red-400 border-red-950/40 bg-red-950/10',
  green: 'text-green-400 border-green-950/40 bg-green-950/10',
  blue:  'text-blue-400 border-blue-950/40 bg-blue-950/10',
  amber: 'text-amber-400 border-amber-950/40 bg-amber-950/10',
};

export function StatCard({
  label,
  value,
  icon: Icon,
  accent = 'blue',
}: {
  label: string;
  value: string | number;
  icon: LucideIcon;
  accent?: keyof typeof ACCENT_STYLES;
}) {
  return (
    <div className={clsx('border rounded-lg p-4 transition-all hover:border-gray-700', ACCENT_STYLES[accent])}>
      <div className="flex items-center justify-between mb-3">
        <span className="text-xs text-gray-500 uppercase font-mono tracking-wider">{label}</span>
        <Icon size={16} className={clsx(ACCENT_STYLES[accent])} />
      </div>
      <p className="text-2xl font-bold font-mono">
        {value}
      </p>
    </div>
  );
}