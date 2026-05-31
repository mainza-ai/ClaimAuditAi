import { useQuery } from '@tanstack/react-query';
import { getStats, getTrends } from '../api/stats';
import { getHeldClaims } from '../api/claims';
import { StatCard } from '../components/stats/StatCard';
import { ClaimRow } from '../components/claims/ClaimRow';
import { formatCurrency } from '../utils/formatCurrency';
import { ShieldAlert, CheckCircle, Activity, Cpu, DollarSign, RefreshCw } from 'lucide-react';

import {
  ResponsiveContainer, LineChart, Line, BarChart, Bar, PieChart, Pie, Cell,
  XAxis, YAxis, Tooltip, CartesianGrid, Legend,
} from 'recharts';

const RISK_COLORS: Record<string, string> = {
  critical: 'var(--color-danger)',
  high: 'var(--color-warning)',
  medium: 'var(--color-success)',
};

const ChartTooltip = ({ active, payload, label }: any) => {
  if (active && payload && payload.length) {
    return (
      <div style={{
        backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-default)',
        borderRadius: 6, padding: '8px 12px', fontSize: 12, color: 'var(--text-primary)',
        boxShadow: 'var(--shadow-modal)',
      }}>
        <p style={{ margin: '0 0 4px', fontWeight: 600, color: 'var(--text-secondary)' }}>{label}</p>
        {payload.map((p: any) => (
          <p key={p.name} style={{ margin: 0, color: p.color }}>
            {p.name}: {typeof p.value === 'number' && p.name.toLowerCase().includes('$') ? formatCurrency(p.value) : p.value}
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
    refetchInterval: 15000,
  });

  const { data: held, isLoading: heldLoading, isError: heldError, isFetching: heldFetching } = useQuery({
    queryKey: ['claims', 'held'],
    queryFn: getHeldClaims,
    refetchInterval: 15000,
  });

  const { data: trends = [] } = useQuery({
    queryKey: ['stats', 'trends'],
    queryFn: getTrends,
    refetchInterval: 30000,
  });

  const allHeld = held ?? [];
  const loading = statsLoading || heldLoading;
  const hasError = statsError || heldError;

  const riskData = stats?.riskDistribution ?? [];
  const dailyData = stats?.dailyInterceptedCounts ?? [];

  const tierData = [
    { name: 'Tier 1 \u2014 NLP', value: riskData.find(d => d.level === 'critical')?.count ?? 0 },
    { name: 'Tier 2 \u2014 Statistical', value: riskData.find(d => d.level === 'high')?.count ?? 0 },
    { name: 'Tier 3 \u2014 Collusion', value: riskData.find(d => d.level === 'medium')?.count ?? 0 },
  ].filter(d => d.value > 0);

  const TIER_PIE_COLORS = ['var(--color-danger)', 'var(--color-warning)', 'var(--color-success)'];
  const hasNonZeroData = dailyData.some(d => d.count > 0);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <h1 style={{ margin: 0, fontSize: 20, fontWeight: 700, letterSpacing: '0.05em', color: 'var(--text-primary)' }}>
          System Overview
        </h1>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontSize: 12, fontFamily: 'var(--font-mono)', padding: '4px 10px', borderRadius: 6, color: 'var(--text-tertiary)', backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-default)' }}>
            Refreshes every 15s
          </span>
          {(statsFetching || heldFetching) && (
            <RefreshCw size={14} style={{ color: 'var(--accent-primary)' }} className="animate-spin" />
          )}
        </div>
      </div>

      {/* Error banner */}
      {hasError && (
        <div style={{ padding: '12px 16px', borderRadius: 8, fontSize: 12, fontFamily: 'var(--font-mono)', backgroundColor: 'var(--color-danger-bg)', border: '1px solid var(--color-danger-border)', color: 'var(--color-danger)' }}>
          Unable to connect to the API. Check that the IRIS container is running and the /api web app is registered.
        </div>
      )}

      {/* Stat cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: 16 }}>
        <StatCard label="Claims on hold" value={stats ? stats.held : (loading ? '...' : '\u2014')} icon={ShieldAlert} accent="red" />
        <StatCard label="Approved today" value={stats ? stats.approvedToday : (loading ? '...' : '\u2014')} icon={CheckCircle} accent="green" />
        <StatCard label="Total Intercepted" value={stats ? stats.interceptedTotal : (loading ? '...' : '\u2014')} icon={Activity} accent="blue" />
        <StatCard label="Total Value Pended" value={stats?.totalValueHeld ? formatCurrency(stats.totalValueHeld) : (loading ? '...' : '$0')} icon={DollarSign} accent="amber" />
        <StatCard label="Model status" value={stats ? stats.modelStatus : (loading ? '...' : '\u2014')} icon={Cpu} accent={stats?.modelStatus === 'healthy' ? 'green' : 'red'} />
      </div>

      {/* Charts grid */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24 }}>
        {/* Chart 1: Daily intercepted line chart */}
        <div className="card" style={{ padding: 20 }}>
          <h3 style={{ margin: '0 0 16px', fontSize: 12, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em', fontFamily: 'var(--font-mono)', color: 'var(--text-secondary)' }}>
            Claims Intercepted (Daily)
          </h3>
          {hasNonZeroData ? (
            <ResponsiveContainer width="100%" height={180}>
              <LineChart data={dailyData}>
                <XAxis dataKey="date" tick={{ fontSize: 11, fill: 'var(--text-tertiary)' }} tickFormatter={d => new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })} />
                <YAxis tick={{ fontSize: 11, fill: 'var(--text-tertiary)' }} allowDecimals={false} />
                <Tooltip content={<ChartTooltip />} />
                <Line type="monotone" dataKey="count" stroke="var(--accent-primary)" strokeWidth={2} dot={{ fill: 'var(--accent-primary)', r: 3 }} />
              </LineChart>
            </ResponsiveContainer>
          ) : (
            <div style={{ height: 180, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 13, color: 'var(--text-tertiary)', fontFamily: 'var(--font-mono)', border: '1px dashed var(--border-default)', borderRadius: 6 }}>
              No interception data yet.
            </div>
          )}
        </div>

        {/* Chart 2: Risk distribution bar chart */}
        <div className="card" style={{ padding: 20 }}>
          <h3 style={{ margin: '0 0 16px', fontSize: 12, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em', fontFamily: 'var(--font-mono)', color: 'var(--text-secondary)' }}>
            Risk Level Distribution
          </h3>
          {riskData.length > 0 ? (
            <ResponsiveContainer width="100%" height={180}>
              <BarChart data={riskData} layout="vertical">
                <XAxis type="number" tick={{ fontSize: 11, fill: 'var(--text-tertiary)' }} allowDecimals={false} />
                <YAxis dataKey="level" type="category" tick={{ fontSize: 11, fill: 'var(--text-tertiary)' }} width={70} />
                <Tooltip content={<ChartTooltip />} />
                <Bar dataKey="count" radius={[0, 4, 4, 0]}>
                  {riskData.map((entry: any) => (
                    <Cell key={entry.level} fill={RISK_COLORS[entry.level] || 'var(--text-tertiary)'} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          ) : (
            <div style={{ height: 180, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 13, color: 'var(--text-tertiary)', fontFamily: 'var(--font-mono)', border: '1px dashed var(--border-default)', borderRadius: 6 }}>
              No risk data yet.
            </div>
          )}
        </div>
      </div>

      {/* Tier breakdown donut */}
      {tierData.length > 0 && (
        <div className="card" style={{ padding: 20 }}>
          <h3 style={{ margin: '0 0 16px', fontSize: 12, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em', fontFamily: 'var(--font-mono)', color: 'var(--text-secondary)' }}>
            Tier Detection Breakdown
          </h3>
          <ResponsiveContainer width="100%" height={200}>
            <PieChart>
              <Pie data={tierData} dataKey="value" innerRadius={50} outerRadius={80} paddingAngle={3}>
                {tierData.map((_, i) => <Cell key={i} fill={TIER_PIE_COLORS[i % TIER_PIE_COLORS.length]} />)}
              </Pie>
              <Tooltip content={<ChartTooltip />} />
              <Legend iconType="circle" iconSize={8} formatter={(v: string) => <span style={{ color: 'var(--text-secondary)', fontSize: 12 }}>{v}</span>} />
            </PieChart>
          </ResponsiveContainer>
        </div>
      )}

      {/* Weekly trend from existing endpoint */}
      <div className="card" style={{ padding: 20 }}>
        <h3 style={{ margin: '0 0 16px', fontSize: 12, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em', fontFamily: 'var(--font-mono)', color: 'var(--text-secondary)' }}>
          Weekly Trend
        </h3>
        {trends.length > 0 ? (
          <ResponsiveContainer width="100%" height={200}>
            <LineChart data={trends}>
              <XAxis dataKey="day" tick={{ fontSize: 11, fill: 'var(--text-tertiary)' }} />
              <YAxis tick={{ fontSize: 11, fill: 'var(--text-tertiary)' }} allowDecimals={false} />
              <CartesianGrid strokeDasharray="3 3" stroke="var(--border-default)" vertical={false} />
              <Tooltip content={<ChartTooltip />} />
              <Legend verticalAlign="top" height={36} iconType="circle" wrapperStyle={{ fontSize: 11, fontFamily: 'var(--font-mono)' }} />
              <Line type="monotone" dataKey="processed" name="Billed" stroke="var(--accent-primary)" strokeWidth={2} dot={false} />
              <Line type="monotone" dataKey="held" name="Held" stroke="var(--color-danger)" strokeWidth={2} dot={false} />
              <Line type="monotone" dataKey="approved" name="Approved" stroke="var(--color-success)" strokeWidth={2} dot={false} />
            </LineChart>
          </ResponsiveContainer>
        ) : (
          <div style={{ height: 200, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 13, color: 'var(--text-tertiary)', fontFamily: 'var(--font-mono)', border: '1px dashed var(--border-default)', borderRadius: 6 }}>
            No trend data available.
          </div>
        )}
      </div>

      {/* Recent holds feed */}
      <section className="card" style={{ padding: 20 }}>
        <h2 style={{ margin: '0 0 16px', fontSize: 12, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em', fontFamily: 'var(--font-mono)', color: 'var(--text-secondary)' }}>
          Recent holds queue
        </h2>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {allHeld.slice(0, 5).map((claim) => (
            <ClaimRow key={claim.id} claim={claim} />
          ))}
          {!allHeld.length && !heldLoading && (
            <div style={{ padding: '48px 0', textAlign: 'center', borderRadius: 8, border: '1px dashed var(--border-default)', color: 'var(--text-secondary)', fontSize: 13 }}>
              No claims on hold. Click <span style={{ color: 'var(--accent-primary)', fontWeight: 700 }}>Seed Sample Data</span> in the top bar to load FHIR sample bundles.
            </div>
          )}
        </div>
      </section>
    </div>
  );
}
