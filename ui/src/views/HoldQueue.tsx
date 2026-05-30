import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { getHeldClaims } from '../api/claims';
import { ClaimRow } from '../components/claims/ClaimRow';
import { Search } from 'lucide-react';
import clsx from 'clsx';


const RISKS = ['all', 'critical', 'high', 'medium'] as const;

export function HoldQueue() {
  const [search, setSearch] = useState('');
  const [selectedRisk, setSelectedRisk] = useState<'all' | 'critical' | 'high' | 'medium'>('all');

  const { data: claims, isLoading } = useQuery({
    queryKey: ['claims', 'held'],
    queryFn: getHeldClaims,
  });

  const allClaims = claims ?? [];

  const filtered = allClaims?.filter(
    (c) =>
      (selectedRisk === 'all' || c.riskLevel === selectedRisk) &&
      (c.id.toLowerCase().includes(search.toLowerCase()) ||
       c.cptCode?.toLowerCase().includes(search.toLowerCase()) ||
       c.patientId?.toLowerCase().includes(search.toLowerCase()))
  );

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-gray-100 tracking-wider">Claims Hold Queue</h1>
        <span className="text-xs font-mono text-gray-500 px-2 py-0.5 bg-gray-900 rounded border border-gray-800">
          {allClaims?.length ?? 0} active pended holds
        </span>
      </div>

      {/* Search & Filters */}
      <div className="space-y-3">
        <div className="relative">
          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500" />
          <input
            type="text"
            placeholder="Search by claim ID, CPT procedure description, or patient ID..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-9 pr-4 py-2 bg-gray-900 border border-gray-800 rounded-lg text-sm text-gray-200 placeholder-gray-600 focus:outline-none focus:border-blue-500 font-mono transition-colors"
          />
        </div>

        {/* Risk chips */}
        <div className="flex flex-wrap gap-2">
          {RISKS.map((r) => {
            const isActive = selectedRisk === r;
            const count = allClaims?.filter((c) => r === 'all' || c.riskLevel === r).length ?? 0;
            return (
              <button
                key={r}
                onClick={() => setSelectedRisk(r)}
                className={clsx(
                  "px-3 py-1.5 rounded-lg text-xs font-semibold capitalize transition-all border",
                  isActive
                    ? r === 'all'
                      ? "bg-blue-500/10 border-blue-500/40 text-blue-400 shadow-[0_0_12px_rgba(59,130,246,0.15)]"
                      : r === 'critical'
                      ? "bg-red-500/10 border-red-500/40 text-red-400 shadow-[0_0_12px_rgba(239,68,68,0.15)]"
                      : r === 'high'
                      ? "bg-orange-500/10 border-orange-500/40 text-orange-400 shadow-[0_0_12px_rgba(249,115,22,0.15)]"
                      : "bg-yellow-500/10 border-yellow-500/40 text-yellow-400 shadow-[0_0_12px_rgba(234,179,8,0.15)]"
                    : "bg-gray-900 border-gray-800 text-gray-400 hover:text-gray-200 hover:border-gray-700"
                )}
              >
                {r} <span className="ml-1 opacity-60 font-mono">({count})</span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Claim list */}
      <div className="space-y-2.5">
        {isLoading && (
          <div className="text-gray-500 text-sm text-center py-16">Loading pended claims...</div>
        )}
        {filtered?.map((claim) => (
          <ClaimRow key={claim.id} claim={claim} />
        ))}
        {filtered?.length === 0 && !isLoading && (
          <div className="text-gray-500 text-sm text-center py-16 border border-dashed border-gray-800 rounded-lg">
            {allClaims.length === 0
              ? <>No claims loaded. Click <span className="text-violet-400 font-bold">Seed Sample Data</span> in the top bar to begin.</>
              : 'No claims match your filter.'
            }
          </div>
        )}
      </div>
    </div>
  );
}