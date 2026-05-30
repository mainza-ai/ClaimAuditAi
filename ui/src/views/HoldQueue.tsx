import { useState, useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { getHeldClaims } from '../api/claims';
import { ClaimRow } from '../components/claims/ClaimRow';
import { Search, ArrowUpDown } from 'lucide-react';


const RISKS = ['all', 'critical', 'high', 'medium'] as const;
type SortKey = 'risk' | 'date' | 'amount';

const ACTIVE_CHIP_STYLES: Record<string, { color: string; borderColor: string; backgroundColor: string; boxShadow: string }> = {
  all:      { color: 'var(--accent-primary)', borderColor: 'var(--border-focus)', backgroundColor: 'var(--accent-subtle)', boxShadow: '0 0 12px var(--accent-subtle)' },
  critical: { color: 'var(--color-danger)', borderColor: 'var(--color-danger-border)', backgroundColor: 'var(--color-danger-bg)', boxShadow: '0 0 12px var(--color-danger-bg)' },
  high:     { color: 'var(--color-warning)', borderColor: 'var(--color-warning-border)', backgroundColor: 'var(--color-warning-bg)', boxShadow: '0 0 12px var(--color-warning-bg)' },
  medium:   { color: 'var(--color-warning)', borderColor: 'var(--color-warning-border)', backgroundColor: 'var(--color-warning-bg)', boxShadow: '0 0 12px var(--color-warning-bg)' },
};

export function HoldQueue() {
  const [search, setSearch] = useState('');
  const [selectedRisk, setSelectedRisk] = useState<'all' | 'critical' | 'high' | 'medium'>('all');
  const [sortKey, setSortKey] = useState<SortKey>('risk');
  const [chipHovered, setChipHovered] = useState<string | null>(null);
  const [searchFocused, setSearchFocused] = useState(false);
  const [sortFocused, setSortFocused] = useState(false);

  const { data: claims, isLoading, isError } = useQuery({
    queryKey: ['claims', 'held'],
    queryFn: getHeldClaims,
  });

  const allClaims = claims ?? [];

  const filtered = useMemo(() => {
    const f = allClaims.filter(
      (c) =>
        (selectedRisk === 'all' || c.riskLevel === selectedRisk) &&
        (c.id.toLowerCase().includes(search.toLowerCase()) ||
         c.cptCode?.toLowerCase().includes(search.toLowerCase()) ||
         c.patientId?.toLowerCase().includes(search.toLowerCase()) ||
         c.patientName?.toLowerCase().includes(search.toLowerCase()))
    );
    const RISK_ORDER = { critical: 0, high: 1, medium: 2 };
    f.sort((a, b) => {
      if (sortKey === 'risk') return (RISK_ORDER[a.riskLevel] ?? 1) - (RISK_ORDER[b.riskLevel] ?? 1);
      if (sortKey === 'date') return new Date(b.lastModified).getTime() - new Date(a.lastModified).getTime();
      return (b.totalAmount ?? 0) - (a.totalAmount ?? 0);
    });
    return f;
  }, [allClaims, search, selectedRisk, sortKey]);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold tracking-wider" style={{ color: 'var(--text-primary)' }}>Claims Hold Queue</h1>
        <span
          className="text-xs font-mono px-2 py-0.5 rounded border"
          style={{ color: 'var(--text-tertiary)', backgroundColor: 'var(--bg-card)', borderColor: 'var(--border-default)' }}
        >
          {allClaims?.length ?? 0} active pended holds
        </span>
      </div>

      {/* Search & Filters */}
      <div className="space-y-3">
        <div className="flex items-center gap-2">
          <div className="relative flex-1">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2" style={{ color: 'var(--text-tertiary)' }} />
            <input
              type="text"
              placeholder="Search by ID, CPT, patient ID, or patient name..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-9 pr-4 py-2 rounded-lg text-sm font-mono transition-colors focus:outline-none"
              style={{
                backgroundColor: 'var(--bg-input)',
                border: searchFocused ? '1px solid var(--border-focus)' : '1px solid var(--border-default)',
                color: 'var(--text-primary)',
              }}
              onFocus={() => setSearchFocused(true)}
              onBlur={() => setSearchFocused(false)}
            />
          </div>
          <div className="relative">
            <select
              value={sortKey}
              onChange={(e) => setSortKey(e.target.value as SortKey)}
              className="appearance-none rounded-lg px-3 py-2 pr-8 text-xs font-mono focus:outline-none cursor-pointer"
              style={{
                backgroundColor: 'var(--bg-input)',
                border: sortFocused ? '1px solid var(--border-focus)' : '1px solid var(--border-default)',
                color: 'var(--text-secondary)',
              }}
              onFocus={() => setSortFocused(true)}
              onBlur={() => setSortFocused(false)}
            >
              <option value="risk" style={{ backgroundColor: 'var(--bg-card)' }}>Sort by risk</option>
              <option value="date" style={{ backgroundColor: 'var(--bg-card)' }}>Sort by date</option>
              <option value="amount" style={{ backgroundColor: 'var(--bg-card)' }}>Sort by amount</option>
            </select>
            <ArrowUpDown size={14} className="absolute right-2.5 top-1/2 -translate-y-1/2 pointer-events-none" style={{ color: 'var(--text-tertiary)' }} />
          </div>
        </div>

        {/* Risk chips */}
        <div className="flex flex-wrap gap-2">
          {RISKS.map((r) => {
            const isActive = selectedRisk === r;
            const isHovered = chipHovered === r;
            const count = allClaims?.filter((c) => r === 'all' || c.riskLevel === r).length ?? 0;
            const activeStyle = ACTIVE_CHIP_STYLES[r];

            return (
              <button
                key={r}
                onClick={() => setSelectedRisk(r)}
                onMouseEnter={() => setChipHovered(r)}
                onMouseLeave={() => setChipHovered(null)}
                className="px-3 py-1.5 rounded-lg text-xs font-semibold capitalize transition-all border"
                style={isActive ? {
                  color: activeStyle.color,
                  borderColor: activeStyle.borderColor,
                  backgroundColor: activeStyle.backgroundColor,
                  boxShadow: activeStyle.boxShadow,
                } : {
                  color: isHovered ? 'var(--text-primary)' : 'var(--text-secondary)',
                  borderColor: isHovered ? 'var(--border-strong)' : 'var(--border-default)',
                  backgroundColor: 'var(--bg-card)',
                }}
              >
                {r} <span className="ml-1 opacity-60 font-mono">({count})</span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Claim list */}
      <div className="space-y-2.5">
        {isError && (
          <div
            className="rounded-lg px-4 py-3 text-xs font-mono"
            style={{
              backgroundColor: 'var(--color-danger-bg)',
              border: '1px solid var(--color-danger-border)',
              color: 'var(--color-danger)',
            }}
          >
            Failed to load claims. Check API connectivity.
          </div>
        )}
        {isLoading && (
          <div className="text-sm text-center py-16" style={{ color: 'var(--text-secondary)' }}>Loading pended claims...</div>
        )}
        {filtered?.map((claim) => (
          <ClaimRow key={claim.id} claim={claim} />
        ))}
        {filtered?.length === 0 && !isLoading && (
          <div
            className="text-sm text-center py-16 rounded-lg border border-dashed"
            style={{ color: 'var(--text-secondary)', borderColor: 'var(--border-default)' }}
          >
            {allClaims.length === 0
              ? <>No claims loaded. Click <span style={{ color: 'var(--accent-primary)', fontWeight: 700 }}>Seed Sample Data</span> in the top bar to begin.</>
              : 'No claims match your filter.'
            }
          </div>
        )}
      </div>
    </div>
  );
}
