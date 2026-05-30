import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getClaimDetail, approveClaim, escalateClaim } from '../api/claims';
import { TierPanel } from '../components/claims/TierPanel';
import { DispositionReader } from '../components/claims/DispositionReader';
import { RiskBadge } from '../components/claims/RiskBadge';
import { useChatStore } from '../store/chatStore';
import { parseDisposition } from '../utils/dispositionParser';
import { CheckCircle, AlertTriangle, ChevronLeft, MessageSquare, HeartPulse, Copy, Check } from 'lucide-react';
import clsx from 'clsx';


export function ClaimDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { setActiveClaim, togglePanel, isOpen } = useChatStore();
  const [copied, setCopied] = useState(false);

  const { data: rawClaim, isLoading } = useQuery({
    queryKey: ['claim', id],
    queryFn: () => getClaimDetail(id!),
    enabled: !!id,
  });

  const claim = rawClaim
    ? {
        ...rawClaim,
        ...parseDisposition(rawClaim.disposition)
      }
    : null;

  useEffect(() => {
    if (claim && id) {
      setActiveClaim(id);
    }
  }, [claim, id, setActiveClaim]);

  const handleCopyDisputeNotice = () => {
    if (!claim) return;
    
    const letter = `
CLAIM INTEGRITY AUDIT - ADMINISTRATIVE HOLD NOTICE
Date: ${new Date().toLocaleDateString()}
Claim Reference ID: ${claim.id}
Patient Reference: ${claim.patientId}
Billed Provider ID: ${claim.providerId || "N/A"}

CPT Procedure Code: ${claim.cptCode}
ICD Diagnostic Code: ${claim.icdCode}
Total Claim Amount: $${claim.totalAmount?.toLocaleString()}

--------------------------------------------------------------------------------
REASON FOR TRANSACTION HOLD:
This claim has been intercepted and placed on a pre-payment administrative integrity hold by the ClaimAuditAI pre-payment integrity engine.

AUDIT SUMMARY & JUSTIFICATION:
${claim.disposition || "Clinical documentation does not support the level of service billed."}

--------------------------------------------------------------------------------
DETERMINATION DETAILS:
- Tier 1 (Semantic Clinical Auditing Mismatch): Mismatch detected between clinical documentation and procedural CPT codes.
- Tier 2 (Statistical Outlier Profiling): Billing reconstruction loss exceeds standard historical deviation.
- Tier 3 (Collusion Network Mapping Analysis): Entity relational cycle detected.

ACTION REQUIRED:
To appeal this payment integrity hold, please submit comprehensive, authenticated clinical SOAP notes, progress documentation, and any corresponding laboratory reports to the Claims Adjudication Portal referencing Claim ID: ${claim.id} within 45 days.

Authorized Integrity Audit Division
ClaimAuditAI Platform (InterSystems IRIS for Health)
`;

    navigator.clipboard.writeText(letter.trim());
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const approve = useMutation({
    mutationFn: () => approveClaim(id!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['claims', 'held'] });
      queryClient.invalidateQueries({ queryKey: ['stats'] });
      navigate('/queue');
    },
  });

  const escalate = useMutation({
    mutationFn: () => escalateClaim(id!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['claim', id] });
    },
  });

  if (isLoading && !claim) {
    return <div className="text-gray-500 text-sm text-center py-16">Retrieving full clinical adjudication...</div>;
  }

  if (!claim) {
    return <div className="text-red-400 text-sm text-center py-16">Adjudication not found.</div>;
  }

  return (
    <div className="space-y-6 max-w-4xl">
      {/* Header */}
      <div className="flex items-start justify-between bg-gray-900 border border-gray-800 rounded-lg p-5">
        <div className="space-y-1">
          <button
            onClick={() => navigate('/queue')}
            className="flex items-center gap-1 text-gray-500 hover:text-gray-300 text-xs font-mono mb-2 focus:outline-none"
          >
            <ChevronLeft size={14} /> back to queue
          </button>
          <h1 className="text-lg font-bold text-gray-100 font-mono uppercase tracking-wider">
            Claim Response {claim.id}
          </h1>
          <p className="text-xs text-gray-500 font-mono">
            Patient: <span className="text-blue-400 font-bold">{claim.patientId}</span>
            {' · '}CPT: <span className="text-gray-300 font-bold">{claim.cptCode}</span>
            {' · '}Total Billed: <span className="text-green-400 font-bold">${claim.totalAmount?.toLocaleString()}</span>
          </p>
        </div>
        <div className="flex items-center gap-3">
          <RiskBadge level={claim.riskLevel} score={claim.riskScore} />
          <button
            onClick={handleCopyDisputeNotice}
            className={clsx(
              "flex items-center gap-2 px-3 py-1.5 rounded text-xs transition-all font-mono border",
              copied
                ? "bg-green-500/20 text-green-400 border-green-500/40 shadow-[0_0_12px_rgba(34,197,94,0.15)]"
                : "bg-gray-800 text-gray-300 hover:bg-gray-700 border-gray-700 hover:border-gray-600"
            )}
          >
            {copied ? <Check size={14} /> : <Copy size={14} />}
            {copied ? 'Copied Notice' : 'Copy Dispute Packet'}
          </button>
          <button
            onClick={() => !isOpen && togglePanel()}
            className="flex items-center gap-2 px-3 py-1.5 rounded bg-blue-600/20 text-blue-400 text-xs hover:bg-blue-600/30 transition-all font-mono border border-blue-700/50"
          >
            <MessageSquare size={14} />
            Ask AI Assistant
          </button>
        </div>
      </div>

      {/* Clinical Notes Summary */}
      {claim.linkedClinicalNotes.length > 0 && (
        <div className="bg-blue-950/10 border border-blue-950/40 rounded-lg p-4">
          <div className="flex items-center gap-2 text-xs font-bold text-blue-400 font-mono uppercase mb-2">
            <HeartPulse size={14} /> Source Clinical Notes (DocumentReference)
          </div>
          {claim.linkedClinicalNotes.map((note, i) => (
            <p key={i} className="text-xs text-gray-400 leading-relaxed font-sans">{note}</p>
          ))}
        </div>
      )}

      {/* Three-tier audit panels */}
      <div className="space-y-3">
        <h2 className="text-xs font-bold text-gray-500 uppercase tracking-widest font-mono">
          Layered payment integrity findings
        </h2>
        {claim.tierResults && claim.tierResults.length > 0 ? (
          claim.tierResults.map((tier) => (
            <TierPanel key={tier.tier} result={tier} />
          ))
        ) : (
          <div className="border border-dashed border-gray-800 rounded-lg p-5 text-center text-gray-500 text-sm font-mono">
            <p>No tier data available</p>
            <p className="text-xs text-gray-600 mt-1">LLM adjudication summary was not generated. Check API key configuration.</p>
          </div>
        )}
      </div>

      {/* Full LLM report */}
      <div className="space-y-2">
        <h2 className="text-xs font-bold text-gray-500 uppercase tracking-widest font-mono">
          Explainable Adjudication justification
        </h2>
        {claim.disposition && !claim.disposition.includes('PYTHON EXCEPTION') ? (
          <DispositionReader markdown={claim.disposition} />
        ) : (
          <div className="bg-gray-900 border border-gray-800 rounded-lg p-5 text-sm text-gray-500 font-mono">
            Full LLM adjudication report not available. The Python agent could not connect to the LLM provider — verify your API key (<code className="text-blue-400">NVIDIA_API_KEY</code>) in the <code className="text-blue-400">.env</code> file and restart the container.
          </div>
        )}
      </div>

      {/* Decision actions */}
      <div className="flex gap-3 pt-4 border-t border-gray-800">
        <button
          onClick={() => approve.mutate()}
          disabled={approve.isPending}
          className="flex items-center gap-2 px-5 py-2.5 bg-green-600 hover:bg-green-500 disabled:opacity-50 text-white rounded-lg text-sm font-semibold transition-all font-mono shadow-md focus:outline-none"
        >
          <CheckCircle size={16} />
          {approve.isPending ? 'Completing Disbursal...' : 'Disburse Claims (Approve)'}
        </button>
        <button
          onClick={() => escalate.mutate()}
          disabled={escalate.isPending}
          className="flex items-center gap-2 px-5 py-2.5 bg-yellow-600/10 hover:bg-yellow-600/20 disabled:opacity-50 text-yellow-500 border border-yellow-800/50 rounded-lg text-sm font-semibold transition-all font-mono focus:outline-none"
        >
          <AlertTriangle size={16} />
          {escalate.isPending ? 'Escalating...' : 'Escalate to Director Review'}
        </button>
      </div>
    </div>
  );
}