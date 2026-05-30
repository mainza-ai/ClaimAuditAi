import { useQuery } from '@tanstack/react-query';
import { getStats, getTrends } from '../api/stats';
import { getHeldClaims } from '../api/claims';
import { StatCard } from '../components/stats/StatCard';
import { ClaimRow } from '../components/claims/ClaimRow';
import { ShieldAlert, CheckCircle, Activity, Cpu, DollarSign, TrendingUp, RefreshCw } from 'lucide-react';

import {
ResponsiveContainer,
AreaChart,
Area,
XAxis,
YAxis,
Tooltip,
CartesianGrid,
Legend
} from 'recharts';

const CustomTooltip = ({ active, payload, label }: any) => {
if (active && payload && payload.length) {
return (
<div
  className="p-3 rounded-lg font-mono text-xs space-y-1"
  style={{
    backgroundColor: 'var(--bg-card)',
    border: '1px solid var(--border-default)',
    boxShadow: 'var(--shadow-modal)',
  }}
>
<p className="font-bold mb-1" style={{ color: 'var(--text-secondary)' }}>{label}</p>
{payload.map((p: any) => (
<p key={p.name} style={{ color: p.color }}>
{p.name}: {p.name.includes('$') || p.name.toLowerCase().includes('leakage') || p.name.toLowerCase().includes('dollars') ? `$${Number(p.value).toLocaleString()}` : p.value}
</p>
))}
</div>
);
}
return null;
};

export function Dashboard() {
const { data: stats, isLoading: statsLoading, isError: statsError, isFetching: statsFetching } = useQuery({
queryKey: ['stats'],
queryFn: getStats,
});

const { data: held, isLoading: heldLoading, isError: heldError, isFetching: heldFetching } = useQuery({
queryKey: ['claims', 'held'],
queryFn: getHeldClaims,
});

const { data: trends = [] } = useQuery({
queryKey: ['stats', 'trends'],
queryFn: getTrends,
});

const allHeld = held ?? [];

const loading = statsLoading || heldLoading;

const totalCapitalHeld = allHeld.reduce((sum, c) => sum + (c.totalAmount || 0), 0);
const leakageRate = stats?.leakageRate ?? 0;
const avoidedLeakage = totalCapitalHeld * leakageRate;

const hasData = !!stats && !statsLoading;
const hasError = statsError || heldError;

return (
<div className="space-y-6">
      <div className="flex items-center justify-between">
<h1 className="text-xl font-bold tracking-wider" style={{ color: 'var(--text-primary)' }}>System Overview</h1>
<div className="flex items-center gap-2">
<span
  className="text-xs font-mono px-2.5 py-1 rounded border"
  style={{ color: 'var(--text-tertiary)', backgroundColor: 'var(--bg-card)', borderColor: 'var(--border-default)' }}
>
Refreshes every 15s
</span>
{(statsFetching || heldFetching) && (
<RefreshCw size={14} style={{ color: 'var(--accent-primary)' }} className="animate-spin" />
)}
</div>
</div>

{hasError && (
<div
  className="rounded-lg px-4 py-3 text-xs font-mono"
  style={{
    backgroundColor: 'var(--color-danger-bg)',
    border: '1px solid var(--color-danger-border)',
    color: 'var(--color-danger)',
  }}
>
Unable to connect to the API. Check that the IRIS container is running and the /api web app is registered.
</div>
)}

{/* Metrics */}
<div className="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
<StatCard
label="Claims on hold"
value={hasData ? stats.held : (loading ? '...' : '—')}
icon={ShieldAlert}
accent="red"
/>
<StatCard
label="Approved today"
value={hasData ? stats.approvedToday : (loading ? '...' : '—')}
icon={CheckCircle}
accent="green"
/>
<StatCard
label="Total Intercepted"
value={hasData ? stats.interceptedTotal : (loading ? '...' : '—')}
icon={Activity}
accent="blue"
/>
<StatCard
label="Total Capital Held"
value={totalCapitalHeld > 0 ? `$${totalCapitalHeld.toLocaleString()}` : (loading ? '...' : '$0')}
icon={DollarSign}
accent="amber"
/>
<StatCard
label="Prevented Leakage"
value={avoidedLeakage > 0 ? `$${avoidedLeakage.toLocaleString(undefined, { maximumFractionDigits: 0 })}` : (loading ? '...' : '$0')}
icon={TrendingUp}
accent="green"
/>
<StatCard
label="Model status"
value={hasData ? stats.modelStatus : (loading ? '...' : '—')}
icon={Cpu}
accent={hasData && stats.modelStatus === 'healthy' ? 'green' : 'red'}
/>
</div>

{/* Recharts Trend Section */}
<div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
{/* Chart 1: Throughput */}
<div
  className="rounded-lg p-5"
  style={{ backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-default)' }}
>
<h3 className="text-sm font-semibold uppercase tracking-wider mb-4 font-mono" style={{ color: 'var(--text-secondary)' }}>
Integrity Throughput (Weekly Volume)
</h3>
<div className="h-64">
{trends.length > 0 ? (
<ResponsiveContainer width="100%" height="100%">
<AreaChart data={trends} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
<defs>
<linearGradient id="colorProcessed" x1="0" y1="0" x2="0" y2="1">
<stop offset="5%" stopColor="#3b82f6" stopOpacity={0.2}/>
<stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
</linearGradient>
<linearGradient id="colorHeld" x1="0" y1="0" x2="0" y2="1">
<stop offset="5%" stopColor="#ef4444" stopOpacity={0.2}/>
<stop offset="95%" stopColor="#ef4444" stopOpacity={0}/>
</linearGradient>
</defs>
<CartesianGrid strokeDasharray="3 3" stroke="#1f2937" vertical={false} />
<XAxis dataKey="day" stroke="#4b5563" fontSize={11} tickLine={false} />
<YAxis stroke="#4b5563" fontSize={11} tickLine={false} />
<Tooltip content={<CustomTooltip />} />
<Legend verticalAlign="top" height={36} iconType="circle" wrapperStyle={{ fontSize: '11px', fontFamily: 'monospace' }} />
<Area type="monotone" dataKey="processed" name="Total Billed Claims" stroke="#3b82f6" strokeWidth={2} fillOpacity={1} fill="url(#colorProcessed)" />
<Area type="monotone" dataKey="held" name="Flagged Held Claims" stroke="#ef4444" strokeWidth={2} fillOpacity={1} fill="url(#colorHeld)" />
</AreaChart>
</ResponsiveContainer>
) : (
<div
  className="h-full flex items-center justify-center text-sm font-mono rounded-lg border border-dashed"
  style={{ color: 'var(--text-tertiary)', borderColor: 'var(--border-default)' }}
>
No trend data available. Seed sample data to populate charts.
</div>
)}
</div>
</div>

{/* Chart 2: Financial Savings */}
<div
  className="rounded-lg p-5"
  style={{ backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-default)' }}
>
<h3 className="text-sm font-semibold uppercase tracking-wider mb-4 font-mono" style={{ color: 'var(--text-secondary)' }}>
Avoided Claims Leakage (Dollars Saved)
</h3>
<div className="h-64">
{trends.length > 0 ? (
<ResponsiveContainer width="100%" height="100%">
<AreaChart data={trends} margin={{ top: 10, right: 10, left: -10, bottom: 0 }}>
<defs>
<linearGradient id="colorLeakage" x1="0" y1="0" x2="0" y2="1">
<stop offset="5%" stopColor="#10b981" stopOpacity={0.2}/>
<stop offset="95%" stopColor="#10b981" stopOpacity={0}/>
</linearGradient>
</defs>
<CartesianGrid strokeDasharray="3 3" stroke="#1f2937" vertical={false} />
<XAxis dataKey="day" stroke="#4b5563" fontSize={11} tickLine={false} />
<YAxis stroke="#4b5563" fontSize={11} tickLine={false} tickFormatter={(v) => `$${v/1000}k`} />
<Tooltip content={<CustomTooltip />} />
<Legend verticalAlign="top" height={36} iconType="circle" wrapperStyle={{ fontSize: '11px', fontFamily: 'monospace' }} />
<Area type="monotone" dataKey="leakagePrevented" name="Leakage Dollars Saved" stroke="#10b981" strokeWidth={2} fillOpacity={1} fill="url(#colorLeakage)" />
</AreaChart>
</ResponsiveContainer>
) : (
<div
  className="h-full flex items-center justify-center text-sm font-mono rounded-lg border border-dashed"
  style={{ color: 'var(--text-tertiary)', borderColor: 'var(--border-default)' }}
>
No trend data available. Seed sample data to populate charts.
</div>
)}
</div>
</div>
</div>

{/* Recent holds feed */}
<section
  className="rounded-lg p-5"
  style={{ backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-default)' }}
>
<h2 className="text-sm font-semibold uppercase tracking-wider mb-4 font-mono" style={{ color: 'var(--text-secondary)' }}>
Recent holds queue
</h2>
<div className="space-y-2.5">
{allHeld.slice(0, 5).map((claim) => (
<ClaimRow key={claim.id} claim={claim} />
))}
{!allHeld.length && !heldLoading && (
<div
  className="text-sm py-12 text-center rounded-lg border border-dashed"
  style={{ color: 'var(--text-secondary)', borderColor: 'var(--border-default)' }}
>
No claims on hold. Click <span style={{ color: 'var(--accent-primary)', fontWeight: 700 }}>Seed Sample Data</span> in the top bar to load FHIR sample bundles.
</div>
)}
</div>
</section>
</div>
);
}
