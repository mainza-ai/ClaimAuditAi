import { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { getClaimDetail } from '../api/claims';
import { TierPanel } from '../components/claims/TierPanel';
import { DispositionReader } from '../components/claims/DispositionReader';
import { RiskBadge } from '../components/claims/RiskBadge';
import { DecisionModal } from '../components/claims/DecisionModal';
import { useChatStore } from '../store/chatStore';
import { useRoleStore } from '../store/roleStore';
import { PERMISSIONS } from '../utils/permissions';
import { parseDisposition } from '../utils/dispositionParser';
import {
  CheckCircle, AlertTriangle, XCircle, ChevronLeft, MessageSquare,
  HeartPulse, Copy, Check, User, Shield,
} from 'lucide-react';

export function ClaimDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const togglePanel = useChatStore((s) => s.togglePanel);
  const isOpen = useChatStore((s) => s.isOpen);
  const activeRole = useRoleStore((s) => s.activeRole);
  const [copied, setCopied] = useState(false);
  const [modal, setModal] = useState<'approve' | 'escalate' | 'reject' | null>(null);

  const { data: rawClaim, isLoading } = useQuery({
    queryKey: ['claim', id],
    queryFn: () => getClaimDetail(id!),
    enabled: !!id,
  });

  const claim = rawClaim
    ? { ...rawClaim, ...parseDisposition(rawClaim.disposition) }
    : null;

  const handleCopyDisputeNotice = () => {
    if (!claim) return;
    const letter = [
      'CLAIM INTEGRITY AUDIT - ADMINISTRATIVE HOLD NOTICE',
      `Date: ${new Date().toLocaleDateString()}`,
      `Claim Reference ID: ${claim.id}`,
      `Patient Reference: ${claim.patientId}`,
      `Billed Provider ID: ${claim.providerId || 'N/A'}`,
      `CPT Procedure Code: ${claim.cptCode}`,
      `ICD Diagnostic Code: ${claim.icdCode}`,
      `Total Claim Amount: $${claim.totalAmount?.toLocaleString()}`,
      '-' .repeat(80),
      'REASON FOR TRANSACTION HOLD:',
      'This claim has been intercepted and placed on a pre-payment administrative integrity hold.',
      'AUDIT SUMMARY & JUSTIFICATION:',
      claim.disposition || 'Clinical documentation does not support the level of service billed.',
      '-' .repeat(80),
      'DETERMINATION DETAILS:',
      '- Tier 1: Semantic Clinical Auditing Mismatch',
      '- Tier 2: Statistical Outlier Profiling',
      '- Tier 3: Collusion Network Mapping Analysis',
      'ACTION REQUIRED:',
      'To appeal, submit comprehensive clinical SOAP notes to Claims Adjudication Portal.',
      'Authorized Integrity Audit Division \u2014 ClaimAuditAI',
    ].join('\n');
    navigator.clipboard.writeText(letter);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleSuccess = () => {
    queryClient.invalidateQueries({ queryKey: ['claims', 'held'], refetchType: 'active' });
    queryClient.invalidateQueries({ queryKey: ['stats'], refetchType: 'active' });
    setModal(null);
    navigate('/queue');
  };

  const userCanApprove = PERMISSIONS.canApprove(activeRole) && !claim?.escalated;
  const userCanEscalate = PERMISSIONS.canEscalate(activeRole);
  const userCanReject = PERMISSIONS.canReject(activeRole) && !claim?.escalated;
  const canTakeAction = userCanApprove || userCanEscalate || userCanReject;

  if (isLoading && !claim) {
    return <div style={{ color: 'var(--text-secondary)', fontSize: 14, textAlign: 'center', padding: '64px 0' }}>Retrieving full clinical adjudication...</div>;
  }
  if (!claim) {
    return <div style={{ color: 'var(--color-danger)', fontSize: 14, textAlign: 'center', padding: '64px 0' }}>Adjudication not found.</div>;
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 24, maxWidth: 896 }}>
      {/* Header */}
      <div className="card" style={{ padding: 20, display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
          <button
            onClick={() => navigate('/queue')}
            style={{ display: 'flex', alignItems: 'center', gap: 4, color: 'var(--text-tertiary)', fontSize: 12, fontFamily: 'var(--font-mono)', background: 'none', border: 'none', cursor: 'pointer', marginBottom: 8, padding: 0 }}
          >
            <ChevronLeft size={14} /> back to queue
          </button>
          <h1 style={{ margin: 0, fontSize: 18, fontWeight: 700, fontFamily: 'var(--font-mono)', textTransform: 'uppercase', letterSpacing: '0.05em', color: 'var(--text-primary)' }}>
            Claim Response {claim.id}
          </h1>
          <p style={{ margin: 0, fontSize: 12, color: 'var(--text-tertiary)', fontFamily: 'var(--font-mono)' }}>
            Patient: <span style={{ color: 'var(--accent-primary)', fontWeight: 700 }}>{claim.patientId}</span>
            {' \u00b7 '}CPT: <span style={{ color: 'var(--text-primary)', fontWeight: 700 }}>{claim.cptCode}</span>
            {' \u00b7 '}Total Billed: <span style={{ color: 'var(--color-success)', fontWeight: 700 }}>${claim.totalAmount?.toLocaleString()}</span>
          </p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <RiskBadge level={claim.riskLevel} score={claim.riskScore} />
          <button
            onClick={handleCopyDisputeNotice}
            style={{
              display: 'flex', alignItems: 'center', gap: 8, padding: '6px 12px', borderRadius: 6,
              fontSize: 12, fontFamily: 'var(--font-mono)', border: '1px solid var(--border-default)',
              backgroundColor: copied ? 'var(--color-success-bg)' : 'var(--bg-card)',
              color: copied ? 'var(--color-success)' : 'var(--text-secondary)',
              cursor: 'pointer',
            }}
          >
            {copied ? <Check size={14} /> : <Copy size={14} />}
            {copied ? 'Copied Notice' : 'Copy Dispute Packet'}
          </button>
          <button
            onClick={() => !isOpen && togglePanel()}
            style={{
              display: 'flex', alignItems: 'center', gap: 8, padding: '6px 12px', borderRadius: 6,
              fontSize: 12, fontFamily: 'var(--font-mono)', border: '1px solid var(--border-focus)',
              backgroundColor: 'var(--accent-subtle)', color: 'var(--accent-text)', cursor: 'pointer',
            }}
          >
            <MessageSquare size={14} /> Ask AI Assistant
          </button>
        </div>
      </div>

      {/* Patient Details Card */}
      <div className="card" style={{ padding: 20 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 12, fontWeight: 700, fontFamily: 'var(--font-mono)', textTransform: 'uppercase', letterSpacing: '0.05em', color: 'var(--accent-primary)', marginBottom: 12 }}>
          <User size={14} /> Patient Information
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16 }}>
          {[
            { label: 'Name', value: claim.patientName || 'Unknown' },
            { label: 'Patient ID', value: claim.patientId, accent: true },
            { label: 'Provider ID', value: claim.providerId || '\u2014' },
            { label: 'Clinical Notes', value: `${claim.linkedClinicalNotes?.length ?? 0} notes` },
          ].map(({ label, value, accent }) => (
            <div key={label}>
              <span style={{ fontSize: 10, color: 'var(--text-tertiary)', textTransform: 'uppercase', fontFamily: 'var(--font-mono)', display: 'block', marginBottom: 4 }}>{label}</span>
              <span style={{ fontSize: 14, fontWeight: 600, fontFamily: 'var(--font-mono)', color: accent ? 'var(--accent-primary)' : 'var(--text-primary)' }}>{value}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Clinical Notes Summary */}
      {claim.linkedClinicalNotes?.length > 0 && (
        <div style={{ padding: 16, borderRadius: 8, backgroundColor: 'var(--accent-subtle)', border: '1px solid var(--border-focus)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 12, fontWeight: 700, fontFamily: 'var(--font-mono)', textTransform: 'uppercase', marginBottom: 8, color: 'var(--accent-primary)' }}>
            <HeartPulse size={14} /> Source Clinical Notes (DocumentReference)
          </div>
          {claim.linkedClinicalNotes.map((note: string, i: number) => (
            <p key={i} style={{ margin: '4px 0', fontSize: 12, color: 'var(--text-secondary)', lineHeight: 1.5 }}>{note}</p>
          ))}
        </div>
      )}

      {/* Three-tier audit panels */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
        <h2 style={{ margin: 0, fontSize: 12, fontWeight: 700, color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.1em', fontFamily: 'var(--font-mono)' }}>
          Layered payment integrity findings
        </h2>
        {claim.tierResults && claim.tierResults.length > 0 ? (
          claim.tierResults.map((tier: any) => (
            <TierPanel key={tier.tier} result={tier} />
          ))
        ) : (
          <div style={{ border: '1px dashed var(--border-default)', borderRadius: 8, padding: 20, textAlign: 'center', color: 'var(--text-tertiary)', fontFamily: 'var(--font-mono)', fontSize: 13 }}>
            <p style={{ margin: 0 }}>No tier data available</p>
            <p style={{ margin: '4px 0 0', fontSize: 11, color: 'var(--text-tertiary)' }}>LLM adjudication summary was not generated. Check API key configuration.</p>
          </div>
        )}
      </div>

      {/* Full LLM report */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        <h2 style={{ margin: 0, fontSize: 12, fontWeight: 700, color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.1em', fontFamily: 'var(--font-mono)' }}>
          Explainable Adjudication justification
        </h2>
        {claim.disposition && !claim.disposition.includes('PYTHON EXCEPTION') ? (
          <DispositionReader markdown={claim.disposition} />
        ) : (
          <div className="card" style={{ padding: 20, fontFamily: 'var(--font-mono)', fontSize: 13, color: 'var(--text-tertiary)' }}>
            Full LLM adjudication report not available. The Python agent could not connect to the LLM provider \u2014 verify your API key (<code style={{ color: 'var(--accent-text)' }}>NVIDIA_API_KEY</code>) in the <code style={{ color: 'var(--accent-text)' }}>.env</code> file and restart the container.
          </div>
        )}
      </div>

      {/* Role indicator */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 10, fontFamily: 'var(--font-mono)', borderRadius: 8, padding: '8px 12px', color: 'var(--text-tertiary)', border: '1px solid var(--border-default)' }}>
        <Shield size={12} />
        Signed in as <span style={{ fontWeight: 700, textTransform: 'uppercase', color: 'var(--text-primary)' }}>{activeRole}</span>
        {claim.escalated ? (
          <span style={{ marginLeft: 4, color: 'var(--color-warning)' }}>\u2014 this claim has been escalated to director</span>
        ) : !canTakeAction ? (
          <span style={{ marginLeft: 4, color: 'var(--color-warning)' }}>\u2014 this role cannot take action on claims</span>
        ) : null}
      </div>

      {/* Decision actions */}
      <div style={{ display: 'flex', gap: 12, paddingTop: 16, borderTop: '1px solid var(--border-default)' }}>
        {PERMISSIONS.canApprove(activeRole) && (
          <button
            onClick={() => setModal('approve')}
            disabled={!userCanApprove}
            style={{
              display: 'flex', alignItems: 'center', gap: 8, padding: '10px 20px', borderRadius: 8,
              fontSize: 14, fontWeight: 600, fontFamily: 'var(--font-mono)', cursor: userCanApprove ? 'pointer' : 'not-allowed',
              backgroundColor: userCanApprove ? 'var(--color-success)' : 'var(--bg-card)',
              color: userCanApprove ? '#fff' : 'var(--text-tertiary)',
              border: userCanApprove ? 'none' : '1px solid var(--border-default)',
              opacity: userCanApprove ? 1 : 0.5,
            }}
          >
            <CheckCircle size={16} /> Disburse (Approve)
          </button>
        )}

        {PERMISSIONS.canEscalate(activeRole) && (
          <button
            onClick={() => setModal('escalate')}
            disabled={!userCanEscalate}
            style={{
              display: 'flex', alignItems: 'center', gap: 8, padding: '10px 20px', borderRadius: 8,
              fontSize: 14, fontWeight: 600, fontFamily: 'var(--font-mono)', cursor: userCanEscalate ? 'pointer' : 'not-allowed',
              backgroundColor: 'transparent',
              color: userCanEscalate ? 'var(--color-warning)' : 'var(--text-tertiary)',
              border: `1px solid ${userCanEscalate ? 'var(--color-warning-border)' : 'var(--border-default)'}`,
              opacity: userCanEscalate ? 1 : 0.5,
            }}
          >
            <AlertTriangle size={16} /> Escalate to Director
          </button>
        )}

        {PERMISSIONS.canReject(activeRole) && (
          <button
            onClick={() => setModal('reject')}
            disabled={!userCanReject}
            style={{
              display: 'flex', alignItems: 'center', gap: 8, padding: '10px 20px', borderRadius: 8,
              fontSize: 14, fontWeight: 600, fontFamily: 'var(--font-mono)', cursor: userCanReject ? 'pointer' : 'not-allowed',
              backgroundColor: 'transparent',
              color: userCanReject ? 'var(--color-danger)' : 'var(--text-tertiary)',
              border: `1px solid ${userCanReject ? 'var(--color-danger-border)' : 'var(--border-default)'}`,
              opacity: userCanReject ? 1 : 0.5,
            }}
          >
            <XCircle size={16} /> Reject Claim
          </button>
        )}
      </div>

      {modal && (
        <DecisionModal
          claimId={claim.id}
          action={modal}
          onConfirm={handleSuccess}
          onCancel={() => setModal(null)}
        />
      )}
    </div>
  );
}
