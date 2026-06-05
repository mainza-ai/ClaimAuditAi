import type { LucideIcon } from 'lucide-react';

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
}: {
  label: string;
  value: string | number;
  icon: LucideIcon;
  accent?: keyof typeof ACCENT_STYLES;
}) {
  const styles = ACCENT_STYLES[accent];

  return (
    <div
      className="border rounded-lg p-4 transition-all"
      style={{
        borderColor: styles.borderColor,
        backgroundColor: styles.backgroundColor,
      }}
    >
      <div className="flex items-center justify-between mb-3">
        <span className="text-xs uppercase font-mono tracking-wider" style={{ color: 'var(--text-secondary)' }}>
          {label}
        </span>
        <Icon size={16} style={{ color: styles.color }} />
      </div>
      <p className="text-2xl font-bold font-mono" style={{ color: 'var(--text-primary)' }}>
        {value}
      </p>
    </div>
  );
}
