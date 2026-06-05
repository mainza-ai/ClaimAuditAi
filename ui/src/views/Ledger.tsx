import { useState, useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { getLedger } from '../api/ledger';
import { ShieldCheck, AlertTriangle, UserCheck, Clock } from 'lucide-react';
import { format } from 'date-fns';

export function Ledger() {
  const [page, setPage] = useState(1);
  const limit = 10;

  const {
    data: response,
    isLoading,
    isError,
  } = useQuery({
    queryKey: ['ledger'],
    queryFn: () => getLedger(200, 0), // Load up to 200 overrides for pagination
    refetchInterval: 30000,
  });

  const entries = response?.data ?? [];
  const totalPages = Math.ceil(entries.length / limit);
  const paginated = useMemo(() => {
    return entries.slice((page - 1) * limit, page * limit);
  }, [entries, page, limit]);

  if (isError) {
    return (
      <div className="space-y-6">
        <div
          style={{
            padding: 24,
            borderRadius: 8,
            backgroundColor: 'var(--color-danger-bg)',
            border: '1px solid var(--color-danger-border)',
            color: 'var(--color-danger)',
            fontSize: 14,
            textAlign: 'center',
          }}
        >
          <AlertTriangle size={24} style={{ marginBottom: 8 }} />
          <p>Failed to load audit ledger. The ledger service may be unavailable.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div
        className="flex items-center justify-between pb-4"
        style={{ borderBottom: '1px solid var(--border-default)' }}
      >
        <div>
          <h1 className="text-xl font-bold tracking-wider" style={{ color: 'var(--text-primary)' }}>
            Override Audit Ledger
          </h1>
          <p className="text-xs font-mono mt-1" style={{ color: 'var(--text-tertiary)' }}>
            System transaction logs and manual adjudication override records
          </p>
        </div>
        <div
          className="flex items-center gap-2 text-xs font-mono px-3 py-1.5 rounded border"
          style={{
            color: 'var(--text-secondary)',
            backgroundColor: 'var(--bg-card)',
            borderColor: 'var(--border-default)',
          }}
        >
          <ShieldCheck size={14} style={{ color: 'var(--color-success)' }} className="animate-pulse" />
          Tamper-Proof Ledger Active
        </div>
      </div>

      <div
        className="rounded-lg overflow-hidden"
        style={{ backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-default)' }}
      >
        {isLoading ? (
          <div className="text-sm py-12 text-center font-mono" style={{ color: 'var(--text-secondary)' }}>
            Loading ledger...
          </div>
        ) : entries.length === 0 ? (
          <div
            className="text-sm py-12 text-center rounded-lg border border-dashed m-4"
            style={{ color: 'var(--text-secondary)', borderColor: 'var(--border-default)' }}
          >
            No override records yet. Approve or escalate held claims to populate the audit ledger.
          </div>
        ) : (
          <table className="w-full text-left font-mono border-collapse">
            <thead>
              <tr
                className="text-xs border-b uppercase tracking-wider"
                style={{
                  backgroundColor: 'var(--bg-page)',
                  color: 'var(--text-tertiary)',
                  borderColor: 'var(--border-default)',
                }}
              >
                <th className="px-5 py-3.5 font-semibold">Tx ID</th>
                <th className="px-5 py-3.5 font-semibold">Claim ID</th>
                <th className="px-5 py-3.5 font-semibold">Type</th>
                <th className="px-5 py-3.5 font-semibold">Billed</th>
                <th className="px-5 py-3.5 font-semibold">Authorizer</th>
                <th className="px-5 py-3.5 font-semibold">Timestamp</th>
                <th className="px-5 py-3.5 font-semibold">Rationale / Override Note</th>
              </tr>
            </thead>
            <tbody
              className="divide-y text-sm"
              style={{ borderColor: 'var(--border-default)', color: 'var(--text-primary)' }}
            >
              {paginated.map((entry) => (
                <tr
                  key={entry.id}
                  className="transition-colors"
                  style={{ borderColor: 'var(--border-default)' }}
                  onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'var(--bg-hover)')}
                  onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'transparent')}
                >
                  <td className="px-5 py-4 font-semibold" style={{ color: 'var(--text-secondary)' }}>
                    {entry.id}
                  </td>
                  <td className="px-5 py-4 font-semibold" style={{ color: 'var(--accent-primary)' }}>
                    #{entry.claimId}
                  </td>
                  <td className="px-5 py-4">
                    <span
                      className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded text-xs border uppercase tracking-wide font-semibold"
                      style={
                        entry.action === 'approved'
                          ? {
                              color: 'var(--color-success)',
                              backgroundColor: 'var(--color-success-bg)',
                              borderColor: 'var(--color-success-border)',
                            }
                          : entry.action === 'rejected'
                            ? {
                                color: 'var(--color-danger)',
                                backgroundColor: 'var(--color-danger-bg)',
                                borderColor: 'var(--color-danger-border)',
                              }
                            : {
                                color: 'var(--color-warning)',
                                backgroundColor: 'var(--color-warning-bg)',
                                borderColor: 'var(--color-warning-border)',
                              }
                      }
                    >
                      {entry.action === 'approved' ? <UserCheck size={12} /> : <AlertTriangle size={12} />}
                      {entry.action}
                    </span>
                  </td>
                  <td className="px-5 py-4 font-semibold" style={{ color: 'var(--text-primary)' }}>
                    ${entry.amount.toLocaleString()}
                  </td>
                  <td className="px-5 py-4 text-xs" style={{ color: 'var(--text-secondary)' }}>
                    {entry.authorizedBy}
                  </td>
                  <td
                    className="px-5 py-4 text-xs flex items-center gap-1.5 pt-5"
                    style={{ color: 'var(--text-tertiary)' }}
                  >
                    <Clock size={12} />
                    {format(new Date(entry.timestamp), 'yyyy-MM-dd HH:mm:ss')}
                  </td>
                  <td
                    className="px-5 py-4 text-xs leading-relaxed max-w-sm whitespace-normal break-words font-sans"
                    style={{ color: 'var(--text-secondary)' }}
                  >
                    {entry.reason}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Pagination Controls */}
      {totalPages > 1 && (
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            paddingTop: 16,
            marginTop: 16,
          }}
        >
          <button
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            disabled={page === 1}
            className="btn-ghost"
            style={{
              fontSize: 12,
              padding: '6px 12px',
              opacity: page === 1 ? 0.5 : 1,
              cursor: page === 1 ? 'not-allowed' : 'pointer',
            }}
          >
            Previous
          </button>
          <span style={{ fontSize: 12, fontFamily: 'monospace', color: 'var(--text-secondary)' }}>
            Page {page} of {totalPages}
          </span>
          <button
            onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
            disabled={page >= totalPages}
            className="btn-ghost"
            style={{
              fontSize: 12,
              padding: '6px 12px',
              opacity: page >= totalPages ? 0.5 : 1,
              cursor: page >= totalPages ? 'not-allowed' : 'pointer',
            }}
          >
            Next
          </button>
        </div>
      )}
    </div>
  );
}
