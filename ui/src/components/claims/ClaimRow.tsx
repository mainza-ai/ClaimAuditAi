import { useNavigate } from 'react-router-dom';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { approveClaim, escalateClaim } from '../../api/claims';
import type { HeldClaim } from '../../types/claim';
import { RiskBadge } from './RiskBadge';
import { formatDistanceToNow } from 'date-fns';
import { ChevronRight, Check, AlertTriangle } from 'lucide-react';
import { useState } from 'react';

const RISK_BORDER_LEFT: Record<string, string> = {
  critical: '4px solid var(--color-danger)',
  high:     '4px solid var(--color-warning)',
  medium:   '4px solid var(--color-warning)',
};

export function ClaimRow({ claim }: { claim: HeldClaim }) {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [hovered, setHovered] = useState(false);

  const approve = useMutation({
    mutationFn: () => approveClaim(claim.id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['claims', 'held'] });
      queryClient.invalidateQueries({ queryKey: ['stats'] });
    },
  });

  const escalate = useMutation({
    mutationFn: () => escalateClaim(claim.id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['claims', 'held'] });
    },
  });

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
          <p className="text-sm font-semibold truncate" style={{ color: 'var(--text-primary)' }}>Claim Response {claim.id}</p>
          <p className="text-xs truncate mt-0.5" style={{ color: 'var(--text-tertiary)' }}>
            Patient {claim.patientId} · CPT {claim.cptCode} · ${claim.totalAmount?.toLocaleString()}
          </p>
        </div>
      </div>
      <div className="flex items-center gap-3 shrink-0 ml-4">
        {hovered && (
          <div className="flex items-center gap-1.5 mr-2">
            <button
              onClick={(e) => {
                e.stopPropagation();
                approve.mutate();
              }}
              disabled={approve.isPending}
              title="Approve / Disburse funds"
              className="p-1.5 rounded disabled:opacity-40 transition-all"
              style={{
                backgroundColor: 'var(--color-success-bg)',
                color: 'var(--color-success)',
                border: '1px solid var(--color-success-border)',
              }}
            >
              <Check size={14} />
            </button>
            <button
              onClick={(e) => {
                e.stopPropagation();
                escalate.mutate();
              }}
              disabled={escalate.isPending}
              title="Escalate to director"
              className="p-1.5 rounded disabled:opacity-40 transition-all"
              style={{
                backgroundColor: 'var(--color-warning-bg)',
                color: 'var(--color-warning)',
                border: '1px solid var(--color-warning-border)',
              }}
            >
              <AlertTriangle size={14} />
            </button>
          </div>
        )}

        <span className="text-xs" style={{ color: 'var(--text-tertiary)' }}>
          {claim.lastModified
            ? formatDistanceToNow(new Date(claim.lastModified), { addSuffix: true })
            : ''}
        </span>
        <ChevronRight size={16} style={{ color: hovered ? 'var(--text-secondary)' : 'var(--text-tertiary)' }} />
      </div>
    </div>
  );
}
