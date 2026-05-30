import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { loadSampleData } from '../../api/claims';
import { useRoleStore, type UserRole } from '../../store/roleStore';
import { Database, ChevronDown, Loader2 } from 'lucide-react';

const ROLES: UserRole[] = ['Auditor', 'Director', 'Specialist', 'Tech Owner / Admin'];

export function TopBar() {
  const queryClient = useQueryClient();
  const { activeRole, setActiveRole } = useRoleStore();
  const [roleOpen, setRoleOpen] = useState(false);

  const seed = useMutation({
    mutationFn: loadSampleData,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['claims'] });
      queryClient.invalidateQueries({ queryKey: ['stats'] });
    },
  });

  return (
    <header className="h-14 border-b border-gray-800 bg-gray-900 px-6 flex items-center justify-between shrink-0">
      <div className="flex items-center gap-2.5">
        <img src="/logo.png" alt="ClaimAuditAI" className="w-5 h-5 object-contain" />
        <span className="text-sm font-semibold tracking-wider uppercase text-gray-200">
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
          disabled={seed.isPending}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded text-xs font-mono font-semibold bg-violet-600/15 text-violet-400 border border-violet-500/30 hover:bg-violet-600/25 hover:border-violet-500/50 transition-all disabled:opacity-50"
        >
          {seed.isPending ? (
            <Loader2 size={13} className="animate-spin" />
          ) : (
            <Database size={13} />
          )}
          {seed.isPending ? 'Seeding...' : 'Seed Sample Data'}
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
        <span className="text-xs text-green-400 font-mono px-2 py-0.5 rounded bg-green-500/10 border border-green-500/20 flex items-center gap-1.5">
          <span className="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse" />
          IRIS Core Live
        </span>
      </div>
    </header>
  );
}