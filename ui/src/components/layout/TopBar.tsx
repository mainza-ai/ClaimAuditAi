import { useState, useEffect, useRef } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { loadSampleData } from '../../api/claims';
import { logout } from '../../api/auth';
import { useRoleStore, type UserRole } from '../../store/roleStore';
import { Database, ChevronDown, Loader2, LogOut } from 'lucide-react';
import { ThemeToggle } from './ThemeToggle';

const ROLES: UserRole[] = ['Auditor', 'Director', 'Specialist', 'Tech Owner / Admin'];

export function TopBar() {
  const queryClient = useQueryClient();
  const { activeRole, setActiveRole, userName } = useRoleStore();
  const [roleOpen, setRoleOpen] = useState(false);
  const [seedDone, setSeedDone] = useState(false);
  const roleRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (roleRef.current && !roleRef.current.contains(e.target as Node)) {
        setRoleOpen(false);
      }
    };
    if (roleOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [roleOpen]);

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
        <button
          onClick={() => seed.mutate()}
          disabled={seed.isPending || seedDone}
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
          {seed.isPending ? 'Seeding...' : seedDone ? 'Seeded!' : 'Seed Sample Data'}
        </button>

        {/* Role selector */}
        <div ref={roleRef} style={{ position: 'relative' }}>
          <button
            onClick={() => setRoleOpen(!roleOpen)}
            style={{
              display: 'flex', alignItems: 'center', gap: 6, padding: '6px 12px', borderRadius: 6,
              fontSize: 12, fontFamily: 'var(--font-mono)', fontWeight: 600, cursor: 'pointer',
              backgroundColor: 'var(--bg-card)', color: 'var(--text-secondary)',
              border: '1px solid var(--border-default)',
            }}
          >
            {activeRole}
            <ChevronDown size={13} style={{ transform: roleOpen ? 'rotate(180deg)' : 'none', transition: 'transform 0.15s' }} />
          </button>
          {roleOpen && (
            <div style={{
              position: 'absolute', right: 0, top: '100%', marginTop: 4, width: 192,
              backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-default)',
              borderRadius: 8, boxShadow: 'var(--shadow-modal)', zIndex: 50, overflow: 'hidden',
            }}>
              {ROLES.map((role) => (
                <button
                  key={role}
                  onClick={() => { setActiveRole(role); setRoleOpen(false); }}
                  style={{
                    width: '100%', textAlign: 'left', padding: '8px 12px',
                    fontSize: 12, fontFamily: 'var(--font-mono)', cursor: 'pointer',
                    backgroundColor: activeRole === role ? 'var(--accent-subtle)' : 'transparent',
                    color: activeRole === role ? 'var(--accent-text)' : 'var(--text-secondary)',
                    fontWeight: activeRole === role ? 700 : 400,
                    border: 'none',
                  }}
                >
                  {role}
                </button>
              ))}
            </div>
          )}
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
          <button onClick={() => { useRoleStore.getState().clearAuth(); logout(); }} title="Sign out" style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-tertiary)', padding: 4 }}>
            <LogOut size={14} />
          </button>
        </div>

        <ThemeToggle />
      </div>
    </header>
  );
}