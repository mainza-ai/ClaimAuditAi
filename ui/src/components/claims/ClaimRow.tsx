import { useNavigate } from 'react-router-dom';
import type { HeldClaim } from '../../types/claim';
import { RiskBadge } from './RiskBadge';
import { formatDistanceToNow } from 'date-fns';
import { ChevronRight } from 'lucide-react';
import { useState } from 'react';

const RISK_BORDER_LEFT: Record<string, string> = {
  critical: '4px solid var(--color-danger)',
  high: '4px solid var(--color-warning)',
  medium: '4px solid var(--color-warning)',
};

export function ClaimRow({ claim }: { claim: HeldClaim }) {
  const navigate = useNavigate();
  const [hovered, setHovered] = useState(false);

  return (
    <div
      role="button"
      tabIndex={0}
      onClick={() => navigate(`/claims/${claim.id}`)}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          navigate(`/claims/${claim.id}`);
        }
      }}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      className="w-full flex items-center justify-between px-4 py-3 rounded-lg cursor-pointer transition-all text-left"
      style={{
        backgroundColor: hovered ? 'var(--bg-hover)' : 'var(--bg-card)',
        border: hovered ? '1px solid var(--border-strong)' : '1px solid var(--border-default)',
        borderLeft: RISK_BORDER_LEFT[claim.riskLevel],
      }}
    >
      <div className="flex items-center gap-4 min-w-0">
        <RiskBadge level={claim.riskLevel} score={claim.riskScore} />
        <div className="min-w-0">
          <p className="text-sm font-semibold truncate" style={{ color: 'var(--text-primary)' }}>
            Claim Response {claim.id}
          </p>
          <p className="text-xs truncate mt-0.5" style={{ color: 'var(--text-tertiary)' }}>
            Patient {claim.patientName || claim.patientId} \u00b7 CPT {claim.cptCode} \u00b7 $
            {claim.totalAmount?.toLocaleString()}
          </p>
        </div>
      </div>
      <div className="flex items-center gap-3 shrink-0 ml-4">
        {claim.escalated ? (
          <span
            style={{
              fontSize: 10,
              fontFamily: 'var(--font-mono)',
              fontWeight: 700,
              textTransform: 'uppercase',
              color: 'var(--color-warning)',
              backgroundColor: 'var(--color-warning-bg)',
              border: '1px solid var(--color-warning-border)',
              padding: '2px 8px',
              borderRadius: 4,
            }}
          >
            Escalated
          </span>
        ) : claim.outcome === 'complete' ? (
          <span
            style={{
              fontSize: 10,
              fontFamily: 'var(--font-mono)',
              fontWeight: 700,
              textTransform: 'uppercase',
              color: 'var(--color-success)',
              backgroundColor: 'var(--color-success-bg)',
              border: '1px solid var(--color-success-border)',
              padding: '2px 8px',
              borderRadius: 4,
            }}
          >
            Approved
          </span>
        ) : claim.outcome === 'error' ? (
          <span
            style={{
              fontSize: 10,
              fontFamily: 'var(--font-mono)',
              fontWeight: 700,
              textTransform: 'uppercase',
              color: 'var(--color-danger)',
              backgroundColor: 'var(--color-danger-bg)',
              border: '1px solid var(--color-danger-border)',
              padding: '2px 8px',
              borderRadius: 4,
            }}
          >
            Rejected
          </span>
        ) : null}

        {hovered && (
          <span
            style={{
              padding: '5px 12px',
              borderRadius: 6,
              border: '1px solid var(--border-default)',
              backgroundColor: 'transparent',
              color: 'var(--text-secondary)',
              fontSize: 12,
              cursor: 'pointer',
              fontFamily: 'var(--font-mono)',
            }}
            onClick={(e) => {
              e.stopPropagation();
              navigate(`/claims/${claim.id}`);
            }}
          >
            Review \u2192
          </span>
        )}

        <span className="text-xs" style={{ color: 'var(--text-tertiary)' }}>
          {claim.lastModified ? formatDistanceToNow(new Date(claim.lastModified), { addSuffix: true }) : ''}
        </span>
        <ChevronRight size={16} style={{ color: hovered ? 'var(--text-secondary)' : 'var(--text-tertiary)' }} />
      </div>
    </div>
  );
}
