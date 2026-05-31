import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { loadSampleData } from '../../api/claims';
import { useRoleStore, type UserRole } from '../../store/roleStore';
import { useUserStore } from '../../store/userStore';
import clsx from 'clsx';
import { Database, ChevronDown, Loader2, LogOut } from 'lucide-react';
import { ThemeToggle } from './ThemeToggle';

const ROLES: UserRole[] = ['Auditor', 'Director', 'Specialist', 'Tech Owner / Admin'];
const ROLE_LABELS: Record<string, string> = { auditor: 'Auditor', director: 'Director', specialist: 'Specialist', admin: 'Tech Owner / Admin' };

export function TopBar() {
  const queryClient = useQueryClient();
  const { activeRole, setActiveRole } = useRoleStore();
  const { name: userName, role: userRole, setUser } = useUserStore();
  const [roleOpen, setRoleOpen] = useState(false);
  const [seedDone, setSeedDone] = useState(false);

  const seed = useMutation({
    mutationFn: loadSampleData,
    onSuccess: () => {
      setSeedDone(true);
      setTimeout(() => setSeedDone(false), 3000);
      queryClient.invalidateQueries({ queryKey: ['claims'], refetchType: 'active' });
      queryClient.invalidateQueries({ queryKey: ['stats'], refetchType: 'active' });
      queryClient.invalidateQueries({ queryKey: ['stats', 'trends'], refetchType: 'active' });
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
        <span className="text-[10px] font-mono font-bold px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
          FHIR R4
        </span>

        {/* InterSystems IRIS badge */}
        <span className="text-[10px] font-mono font-bold px-2 py-0.5 rounded bg-blue-500/10 text-blue-400 border border-blue-500/20">
          InterSystems IRIS
        </span>

        {/* Seed Sample Data button */}
        <button
          onClick={() => seed.mutate()}
          disabled={seed.isPending || seedDone}
          className={clsx(
            "flex items-center gap-1.5 px-3 py-1.5 rounded text-xs font-mono font-semibold transition-all disabled:opacity-50 border",
            seedDone
              ? "bg-green-600/15 text-green-400 border-green-500/30 shadow-[0_0_8px_rgba(34,197,94,0.2)]"
              : "bg-violet-600/15 text-violet-400 border-violet-500/30 hover:bg-violet-600/25 hover:border-violet-500/50"
          )}
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
        <div className="relative">
          <button
            onClick={() => setRoleOpen(!roleOpen)}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded text-xs font-mono font-semibold bg-gray-800 text-gray-300 border border-gray-700 hover:border-gray-600 hover:text-gray-100 transition-all"
          >
            {activeRole}
            <ChevronDown size={13} className={`transition-transform ${roleOpen ? 'rotate-180' : ''}`} />
          </button>
          {roleOpen && (
            <div className="absolute right-0 top-full mt-1 w-48 bg-gray-900 border border-gray-800 rounded-lg shadow-2xl z-50 overflow-hidden">
              {ROLES.map((role) => (
                <button
                  key={role}
                  onClick={() => { setActiveRole(role); setRoleOpen(false); }}
                  className={`w-full text-left px-3 py-2 text-xs font-mono transition-colors ${
                    activeRole === role
                      ? 'bg-blue-600/20 text-blue-400 font-bold'
                      : 'text-gray-400 hover:bg-gray-800 hover:text-gray-200'
                  }`}
                >
                  {role}
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Live status */}
        <span style={{
          fontSize: 11,
          color: 'var(--color-success)',
          fontFamily: 'var(--font-mono)',
          padding: '3px 10px',
          borderRadius: 6,
          backgroundColor: 'var(--color-success-bg)',
          border: '1px solid var(--color-success-border)',
          display: 'flex',
          alignItems: 'center',
          gap: 6,
        }}>
          <span style={{ width: 6, height: 6, borderRadius: '50%', backgroundColor: 'var(--color-success)' }} />
          IRIS Core Live
        </span>

        {/* User identity badge */}
        {userName && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <div style={{ width: 28, height: 28, borderRadius: '50%', backgroundColor: 'var(--accent-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'white', fontSize: 11, fontWeight: 700 }}>
              {userName.split(' ').map(n => n[0]).join('').slice(0, 2).toUpperCase()}
            </div>
            <div>
              <p style={{ margin: 0, fontSize: 12, fontWeight: 500, color: 'var(--text-primary)' }}>{userName}</p>
              <p style={{ margin: 0, fontSize: 10, color: 'var(--text-tertiary)' }}>{ROLE_LABELS[userRole] || activeRole}</p>
            </div>
            <button onClick={() => setUser('', 'auditor')} title="Switch user" style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-tertiary)', padding: 4 }}>
              <LogOut size={14} />
            </button>
          </div>
        )}

        <ThemeToggle />
      </div>
    </header>
  );
}