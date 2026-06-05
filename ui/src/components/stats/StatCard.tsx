import type { LucideIcon } from 'lucide-react';
import { HelpCircle } from 'lucide-react';

const ACCENT_STYLES: Record<string, { color: string; borderColor: string; backgroundColor: string }> = {
  red: {
    color: 'var(--color-danger)',
    borderColor: 'var(--color-danger-border)',
    backgroundColor: 'var(--color-danger-bg)',
  },
  green: {
    color: 'var(--color-success)',
    borderColor: 'var(--color-success-border)',
    backgroundColor: 'var(--color-success-bg)',
  },
  blue: { color: 'var(--accent-primary)', borderColor: 'var(--border-focus)', backgroundColor: 'var(--accent-subtle)' },
  amber: {
    color: 'var(--color-warning)',
    borderColor: 'var(--color-warning-border)',
    backgroundColor: 'var(--color-warning-bg)',
  },
};

export function StatCard({
  label,
  value,
  icon: Icon,
  accent = 'blue',
  tooltip,
}: {
  label: string;
  value: string | number;
  icon: LucideIcon;
  accent?: keyof typeof ACCENT_STYLES;
  tooltip?: string;
}) {
  const styles = ACCENT_STYLES[accent];

  return (
    <div
      className="border rounded-lg p-4 transition-all"
      style={{
        borderColor: styles.borderColor,
        backgroundColor: styles.backgroundColor,
        position: 'relative',
      }}
    >
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-1.5">
          <span className="text-xs uppercase font-mono tracking-wider" style={{ color: 'var(--text-secondary)' }}>
            {label}
          </span>
          {tooltip && (
            <div className="group relative flex items-center">
              <HelpCircle size={12} style={{ color: 'var(--text-tertiary)', cursor: 'help' }} />
              <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 hidden group-hover:block w-48 p-2 rounded bg-slate-900 text-xs font-sans text-slate-100 border border-slate-700 shadow-lg z-50 text-center leading-normal">
                {tooltip}
                <div className="absolute top-full left-1/2 -translate-x-1/2 -mt-1 border-4 border-transparent border-t-slate-900"></div>
              </div>
            </div>
          )}
        </div>
        <Icon size={16} style={{ color: styles.color }} />
      </div>
      <p className="text-2xl font-bold font-mono" style={{ color: 'var(--text-primary)' }}>
        {value}
      </p>
    </div>
  );
}

