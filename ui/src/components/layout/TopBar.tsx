import { useState, useEffect } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { loadSampleData } from '../../api/claims';
import { logout } from '../../api/auth';
import { useRoleStore } from '../../store/roleStore';
import { PERMISSIONS } from '../../utils/permissions';
import { Database, Loader2, LogOut } from 'lucide-react';
import { ThemeToggle } from './ThemeToggle';

export function TopBar() {
  const queryClient = useQueryClient();
  const { activeRole, userName } = useRoleStore();
  const [seedDone, setSeedDone] = useState(false);
  const [seedElapsed, setSeedElapsed] = useState(0);

  const seed = useMutation({
    mutationFn: loadSampleData,
    onSuccess: () => {
      setSeedDone(true);
      setTimeout(() => setSeedDone(false), 3000);
      queryClient.invalidateQueries({ queryKey: ['claims'], refetchType: 'active' });
      queryClient.invalidateQueries({ queryKey: ['stats'], refetchType: 'active' });
      queryClient.invalidateQueries({ queryKey: ['stats', 'trends'], refetchType: 'active' });
      queryClient.invalidateQueries({ queryKey: ['ledger'] });
      queryClient.invalidateQueries({ queryKey: ['graph'] });
    },
  });

  useEffect(() => {
    let timer: ReturnType<typeof setInterval>;
    if (seed.isPending) {
      setSeedElapsed(0);
      timer = setInterval(() => setSeedElapsed((p) => p + 1), 1000);
    }
    return () => clearInterval(timer);
  }, [seed.isPending]);

  return (
    <header
      style={{
        height: 56,
        backgroundColor: 'var(--bg-topbar)',
        borderBottom: '1px solid var(--border-default)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '0 24px',
        flexShrink: 0,
      }}
    >
      <div className="flex items-center gap-2.5">
        <img src="/logo.png" alt="ClaimAuditAI" className="w-5 h-5 object-contain" />
        <span style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-primary)' }}>
          ClaimAuditAI Adjudicator
        </span>
      </div>

      <div className="flex items-center gap-3">
        {/* FHIR R4 badge */}
        <span style={{ fontSize: 10, fontFamily: 'var(--font-mono)', fontWeight: 700, padding: '2px 8px', borderRadius: 4, backgroundColor: 'var(--color-success-bg)', color: 'var(--color-success)', border: '1px solid var(--color-success-border)' }}>
          FHIR R4
        </span>

        {/* InterSystems IRIS badge */}
        <span style={{ fontSize: 10, fontFamily: 'var(--font-mono)', fontWeight: 700, padding: '2px 8px', borderRadius: 4, backgroundColor: 'var(--accent-subtle)', color: 'var(--accent-text)', border: '1px solid var(--border-focus)' }}>
          InterSystems IRIS
        </span>

        {/* Seed Sample Data button */}
        {PERMISSIONS.canManageData(activeRole) && (
        <button
          onClick={() => !seed.isPending && !seedDone && seed.mutate()}
          disabled={seed.isPending || seedDone}
          aria-label={seed.isPending ? 'Seeding sample data...' : seedDone ? 'Sample data seeded' : 'Seed sample data'}
          style={{
            display: 'flex', alignItems: 'center', gap: 6, padding: '6px 12px', borderRadius: 6,
            fontSize: 12, fontFamily: 'var(--font-mono)', fontWeight: 600, cursor: 'pointer',
            border: '1px solid var(--accent-primary)',
            backgroundColor: seedDone ? 'var(--color-success-bg)' : 'var(--accent-subtle)',
            color: seedDone ? 'var(--color-success)' : 'var(--accent-text)',
            opacity: (seed.isPending || seedDone) ? 0.6 : 1,
          }}
        >
          {seed.isPending ? (
            <Loader2 size={13} className="animate-spin" />
          ) : seedDone ? (
            <Database size={13} />
          ) : (
            <Database size={13} />
          )}
          {seed.isPending ? `Seeding... (${seedElapsed}s)` : seedDone ? 'Seeded!' : 'Seed Sample Data'}
        </button>
        )}

        {/* Role badge — derived from JWT, display only. Authority enforced by backend. */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: 6, padding: '6px 12px', borderRadius: 6,
          fontSize: 12, fontFamily: 'var(--font-mono)', fontWeight: 600,
          backgroundColor: 'var(--bg-card)', color: 'var(--text-secondary)',
          border: '1px solid var(--border-default)',
        }}>
          {activeRole}
        </div>

        {/* User identity badge */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 28, height: 28, borderRadius: '50%', backgroundColor: 'var(--accent-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'white', fontSize: 11, fontWeight: 700 }}>
            {userName.split(' ').map((n: string) => n[0]).join('').slice(0, 2).toUpperCase()}
          </div>
          <div>
            <p style={{ margin: 0, fontSize: 12, fontWeight: 500, color: 'var(--text-primary)' }}>{userName}</p>
            <p style={{ margin: 0, fontSize: 10, color: 'var(--text-tertiary)' }}>{activeRole}</p>
          </div>
          <button onClick={() => { useRoleStore.getState().clearAuth(); logout(); }} title="Sign out" aria-label="Sign out" style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-tertiary)', padding: 4 }}>
            <LogOut size={14} />
          </button>
        </div>

        <ThemeToggle />
      </div>
    </header>
  );
}