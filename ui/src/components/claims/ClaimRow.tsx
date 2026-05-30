import { useNavigate } from 'react-router-dom';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { approveClaim, escalateClaim } from '../../api/claims';
import type { HeldClaim } from '../../types/claim';
import { RiskBadge } from './RiskBadge';
import { formatDistanceToNow } from 'date-fns';
import { ChevronRight, Check, AlertTriangle } from 'lucide-react';
import clsx from 'clsx';

const RISK_BORDER = {
  critical: 'border-l-4 border-l-red-500',
  high:     'border-l-4 border-l-orange-500',
  medium:   'border-l-4 border-l-yellow-500',
};

export function ClaimRow({ claim }: { claim: HeldClaim }) {
  const navigate = useNavigate();
  const queryClient = useQueryClient();

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
      className={clsx(
        "w-full flex items-center justify-between px-4 py-3 bg-gray-900 border border-gray-800 rounded-lg hover:border-gray-700 hover:bg-gray-800/60 cursor-pointer transition-all text-left group",
        RISK_BORDER[claim.riskLevel]
      )}
    >
      <div className="flex items-center gap-4 min-w-0">
        <RiskBadge level={claim.riskLevel} score={claim.riskScore} />
        <div className="min-w-0">
          <p className="text-sm font-semibold text-gray-200 truncate">Claim Response {claim.id}</p>
          <p className="text-xs text-gray-500 truncate mt-0.5">
            Patient {claim.patientId} · CPT {claim.cptCode} · ${claim.totalAmount?.toLocaleString()}
          </p>
        </div>
      </div>
      <div className="flex items-center gap-3 shrink-0 ml-4">
        {/* Hover Quick Actions */}
        <div className="hidden group-hover:flex items-center gap-1.5 mr-2">
          <button
            onClick={(e) => {
              e.stopPropagation();
              approve.mutate();
            }}
            disabled={approve.isPending}
            title="Approve / Disburse funds"
            className="p-1.5 rounded bg-green-500/10 hover:bg-green-500/30 text-green-400 border border-green-500/20 disabled:opacity-40 transition-all"
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
            className="p-1.5 rounded bg-yellow-500/10 hover:bg-yellow-500/30 text-yellow-400 border border-yellow-500/20 disabled:opacity-40 transition-all"
          >
            <AlertTriangle size={14} />
          </button>
        </div>

        <span className="text-xs text-gray-500">
          {claim.lastModified
            ? formatDistanceToNow(new Date(claim.lastModified), { addSuffix: true })
            : ''}
        </span>
        <ChevronRight size={16} className="text-gray-600 group-hover:text-gray-400 transition-colors" />
      </div>
    </div>
  );
}