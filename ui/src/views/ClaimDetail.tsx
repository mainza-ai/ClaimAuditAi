import { useState, useEffect } from 'react';
import { useParams, useNavigate, useLocation } from 'react-router-dom';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { getClaimDetail, reauditClaim, generateReport } from '../api/claims';
import { TierPanel } from '../components/claims/TierPanel';
import { DispositionReader } from '../components/claims/DispositionReader';
import { RiskBadge } from '../components/claims/RiskBadge';
import { DecisionModal } from '../components/claims/DecisionModal';
import { useChatStore } from '../store/chatStore';
import { useRoleStore } from '../store/roleStore';
import { PERMISSIONS } from '../utils/permissions';
import { parseDisposition } from '../utils/dispositionParser';
import type { AuditTierResult } from '../types/claim';
import {
  CheckCircle,
  AlertTriangle,
  XCircle,
  RefreshCw,
  ChevronLeft,
  MessageSquare,
  HeartPulse,
  Copy,
  Check,
  User,
  Shield,
  Building,
} from 'lucide-react';

export function ClaimDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const location = useLocation();
  const queryClient = useQueryClient();
  const togglePanel = useChatStore((s) => s.togglePanel);
  const isOpen = useChatStore((s) => s.isOpen);
  const activeRole = useRoleStore((s) => s.activeRole);
  const [copied, setCopied] = useState(false);
  const [modal, setModal] = useState<'approve' | 'escalate' | 'reject' | null>(null);
  const [generatingReport, setGeneratingReport] = useState(false);
  const [generatedReportText, setGeneratedReportText] = useState<string | null>(null);
  const [reauditing, setReauditing] = useState(false);
  const [expandedNote, setExpandedNote] = useState<number | null>(0);

  const fromLedger = location.state?.from === 'ledger';

  const {
    data: rawClaim,
    isLoading,
    isError,
  } = useQuery({
    queryKey: ['claim', id],
    queryFn: () => getClaimDetail(id!),
    enabled: !!id,
  });

  const claim = rawClaim
    ? {
        ...parseDisposition(rawClaim.disposition),
        ...rawClaim,
        tierResults:
          rawClaim.tierResults && rawClaim.tierResults.length > 0
            ? rawClaim.tierResults
            : parseDisposition(rawClaim.disposition).tierResults,
      }
    : null;

  useEffect(() => {
    if (claim && claim.reportStatus === 'pending' && !generatingReport && !generatedReportText) {
      setGeneratingReport(true);
      generateReport(id!)
        .then((res) => {
          setGeneratedReportText(res.disposition);
          queryClient.invalidateQueries({ queryKey: ['claim', id] });
        })
        .catch((err) => {
          console.error("Failed to generate report", err);
        })
        .finally(() => {
          setGeneratingReport(false);
        });
    }
  }, [claim?.reportStatus, id, generatingReport, generatedReportText, queryClient]);

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
      '-'.repeat(80),
      'REASON FOR TRANSACTION HOLD:',
      'This claim has been intercepted and placed on a pre-payment administrative integrity hold.',
      'AUDIT SUMMARY & JUSTIFICATION:',
      (generatedReportText || claim.disposition) || 'Clinical documentation does not support the level of service billed.',
      '-'.repeat(80),
      'DETERMINATION DETAILS:',
      '- Tier 1: Semantic Clinical Auditing Mismatch',
      '- Tier 2: Statistical Outlier Profiling',
      '- Tier 3: Collusion Network Mapping Analysis',
      'ACTION REQUIRED:',
      'To appeal, submit comprehensive clinical SOAP notes to Claims Adjudication Portal.',
      'Authorized Integrity Audit Division — ClaimAuditAI',
    ].join('\n');
    navigator.clipboard.writeText(letter);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleSuccess = () => {
    queryClient.removeQueries({ queryKey: ['claims', 'held'] });
    queryClient.invalidateQueries({ queryKey: ['stats'] });
    queryClient.invalidateQueries({ queryKey: ['ledger'] });
    setModal(null);
    navigate('/queue');
  };

  const handleReaudit = async () => {
    if (!id) return;
    setReauditing(true);
    try {
      setGeneratedReportText(null);
      await reauditClaim(id);
      queryClient.invalidateQueries({ queryKey: ['claim', id] });
      queryClient.invalidateQueries({ queryKey: ['claims', 'held'] });
    } catch (e) {
      console.error('Reaudit failed', e);
    } finally {
      setReauditing(false);
    }
  };

  const getCptStatus = (code: string) => {
    if (!claim || !claim.disposition) return { label: 'Validated', color: 'var(--color-success)' };
    const lowerDisp = claim.disposition.toLowerCase();
    if (
      lowerDisp.includes(code.toLowerCase()) &&
      (lowerDisp.includes('mismatch') ||
        lowerDisp.includes('invalid') ||
        lowerDisp.includes('conflict') ||
        lowerDisp.includes('not match'))
    ) {
      return { label: 'Mismatch Flagged', color: 'var(--color-danger)' };
    }
    return { label: 'Validated', color: 'var(--color-success)' };
  };

  const getIcdStatus = (code: string) => {
    if (!claim || !claim.disposition) return { label: 'Validated', color: 'var(--color-success)' };
    const lowerDisp = claim.disposition.toLowerCase();
    if (
      lowerDisp.includes(code.toLowerCase()) &&
      (lowerDisp.includes('mismatch') ||
        lowerDisp.includes('invalid') ||
        lowerDisp.includes('conflict') ||
        lowerDisp.includes('not match'))
    ) {
      return { label: 'Mismatch Flagged', color: 'var(--color-danger)' };
    }
    return { label: 'Validated', color: 'var(--color-success)' };
  };

  const canReaudit = PERMISSIONS.canReaudit(activeRole) || activeRole === 'Auditor' || activeRole === 'Director' || activeRole === 'Specialist';

  const isDecided = claim?.outcome === 'complete' || claim?.outcome === 'error';
  const userCanApprove = PERMISSIONS.canApprove(activeRole) && !isDecided;
  const userCanEscalate = PERMISSIONS.canEscalate(activeRole) && !claim?.escalated && !isDecided;
  const userCanReject = PERMISSIONS.canReject(activeRole) && !isDecided;
  const canTakeAction = userCanApprove || userCanEscalate || userCanReject;

  if (isLoading && !claim) {
    return (
      <div style={{ color: 'var(--text-secondary)', fontSize: 14, textAlign: 'center', padding: '64px 0' }}>
        Retrieving full clinical adjudication...
      </div>
    );
  }
  if (isError) {
    return (
      <div style={{ color: 'var(--color-danger)', fontSize: 14, textAlign: 'center', padding: '64px 0' }}>
        Failed to load claim data. Please try again.
      </div>
    );
  }
  if (!claim) {
    return (
      <div style={{ color: 'var(--color-danger)', fontSize: 14, textAlign: 'center', padding: '64px 0' }}>
        Adjudication not found.
      </div>
    );
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 24, maxWidth: 896 }}>
      {/* Header */}
      <div
        className="card"
        style={{ padding: 20, display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
          <button
            onClick={() => navigate(fromLedger ? '/ledger' : '/queue')}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 4,
              color: 'var(--text-tertiary)',
              fontSize: 12,
              fontFamily: 'var(--font-mono)',
              background: 'none',
              border: 'none',
              cursor: 'pointer',
              marginBottom: 8,
              padding: 0,
            }}
          >
            <ChevronLeft size={14} /> back to {fromLedger ? 'ledger' : 'queue'}
          </button>
          <h1
            style={{
              margin: 0,
              fontSize: 18,
              fontWeight: 700,
              fontFamily: 'var(--font-mono)',
              textTransform: 'uppercase',
              letterSpacing: '0.05em',
              color: 'var(--text-primary)',
            }}
          >
            Claim Response {claim.id}
          </h1>
          <p style={{ margin: 0, fontSize: 12, color: 'var(--text-tertiary)', fontFamily: 'var(--font-mono)' }}>
            Patient: <span style={{ color: 'var(--accent-primary)', fontWeight: 700 }}>{claim.patientId}</span>
            {' \u00b7 '}Provider:{' '}
            <span style={{ color: 'var(--accent-primary)', fontWeight: 700 }}>{claim.providerId}</span>
            {' \u00b7 '}CPT: <span style={{ color: 'var(--text-primary)', fontWeight: 700 }}>{claim.cptCode}</span>
            {' \u00b7 '}ICD: <span style={{ color: 'var(--text-primary)', fontWeight: 700 }}>{claim.icdCode}</span>
            {' \u00b7 '}Total Billed:{' '}
            <span style={{ color: 'var(--color-success)', fontWeight: 700 }}>
              ${claim.totalAmount?.toLocaleString()}
            </span>
          </p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <RiskBadge level={claim.riskLevel} score={claim.riskScore} />
          <button
            onClick={handleCopyDisputeNotice}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              padding: '6px 12px',
              borderRadius: 6,
              fontSize: 12,
              fontFamily: 'var(--font-mono)',
              border: '1px solid var(--border-default)',
              backgroundColor: copied ? 'var(--color-success-bg)' : 'var(--bg-card)',
              color: copied ? 'var(--color-success)' : 'var(--text-secondary)',
              cursor: 'pointer',
            }}
          >
            {copied ? <Check size={14} /> : <Copy size={14} />}
            {copied ? 'Copied Notice' : 'Copy Dispute Packet'}
          </button>
          {canReaudit && (
            <button
              onClick={handleReaudit}
              disabled={reauditing}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 8,
                padding: '6px 12px',
                borderRadius: 6,
                fontSize: 12,
                fontFamily: 'var(--font-mono)',
                border: '1px solid var(--border-default)',
                backgroundColor: 'var(--bg-card)',
                color: 'var(--text-secondary)',
                cursor: reauditing ? 'not-allowed' : 'pointer',
              }}
            >
              <RefreshCw size={14} className={reauditing ? 'animate-spin' : ''} />
              Re-run AI Adjudication
            </button>
          )}
          <button
            onClick={() => !isOpen && togglePanel()}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              padding: '6px 12px',
              borderRadius: 6,
              fontSize: 12,
              fontFamily: 'var(--font-mono)',
              border: '1px solid var(--border-focus)',
              backgroundColor: 'var(--accent-subtle)',
              color: 'var(--accent-text)',
              cursor: 'pointer',
            }}
          >
            <MessageSquare size={14} /> Ask AI Assistant
          </button>
        </div>
      </div>

      {/* Audit Override Log Status Banner */}
      {isDecided && (
        <div
          style={{
            padding: 16,
            borderRadius: 8,
            backgroundColor: claim.outcome === 'complete' ? 'var(--color-success-bg)' : 'var(--color-danger-bg)',
            border: `1px solid ${claim.outcome === 'complete' ? 'var(--color-success-border)' : 'var(--color-danger-border)'}`,
            display: 'flex',
            flexDirection: 'column',
            gap: 8,
            fontFamily: 'var(--font-mono)',
          }}
        >
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              fontSize: 13,
              fontWeight: 700,
              textTransform: 'uppercase',
              color: claim.outcome === 'complete' ? 'var(--color-success)' : 'var(--color-danger)',
            }}
          >
            {claim.outcome === 'complete' ? <CheckCircle size={16} /> : <XCircle size={16} />}
            Override Decision Resolved & Ledgered: {claim.outcome === 'complete' ? 'Approved' : 'Rejected'}
          </div>
          <div style={{ fontSize: 12, color: 'var(--text-secondary)' }}>
            <div>
              <strong>Authorized By:</strong>{' '}
              {claim.actionHistory && [...claim.actionHistory].reverse().find((h) => h.type === 'authorized-by')?.value || 'System/Auditor'}
            </div>
            {claim.actionHistory && [...claim.actionHistory].reverse().find((h) => h.type === 'decision-timestamp')?.value && (
              <div style={{ marginTop: 2 }}>
                <strong>Decided At:</strong>{' '}
                {new Date([...claim.actionHistory].reverse().find((h) => h.type === 'decision-timestamp')!.value).toLocaleString()}
              </div>
            )}
            {claim.actionHistory && [...claim.actionHistory].reverse().find((h) => h.type === 'rationale')?.value && (
              <div
                style={{
                  marginTop: 6,
                  paddingTop: 6,
                  borderTop: '1px dashed var(--border-default)',
                  fontSize: 12,
                  lineHeight: 1.4,
                  fontFamily: 'var(--font-sans)',
                  color: 'var(--text-primary)',
                }}
              >
                <strong>Override Rationale Note:</strong>{' '}
                {[...claim.actionHistory].reverse().find((h) => h.type === 'rationale')!.value}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Patient Details Card */}
      <div className="card" style={{ padding: 20 }}>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            fontSize: 12,
            fontWeight: 700,
            fontFamily: 'var(--font-mono)',
            textTransform: 'uppercase',
            letterSpacing: '0.05em',
            color: 'var(--accent-primary)',
            marginBottom: 12,
          }}
        >
          <User size={14} /> Patient Information
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16 }}>
          {[
            { label: 'Name', value: claim.patientName || 'Unknown' },
            { label: 'Patient ID', value: claim.patientId, accent: true },
            { label: 'Clinical Notes', value: `${claim.linkedClinicalNotes?.length ?? 0} notes` },
          ].map(({ label, value, accent }) => (
            <div key={label}>
              <span
                style={{
                  fontSize: 10,
                  color: 'var(--text-tertiary)',
                  textTransform: 'uppercase',
                  fontFamily: 'var(--font-mono)',
                  display: 'block',
                  marginBottom: 4,
                }}
              >
                {label}
              </span>
              <span
                style={{
                  fontSize: 14,
                  fontWeight: 600,
                  fontFamily: 'var(--font-mono)',
                  color: accent ? 'var(--accent-primary)' : 'var(--text-primary)',
                }}
              >
                {value}
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* Provider Details Card */}
      <div className="card" style={{ padding: 20 }}>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            fontSize: 12,
            fontWeight: 700,
            fontFamily: 'var(--font-mono)',
            textTransform: 'uppercase',
            letterSpacing: '0.05em',
            color: 'var(--accent-primary)',
            marginBottom: 12,
          }}
        >
          <Building size={14} /> Provider Information
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16 }}>
          {[
            { label: 'Name', value: claim.providerName || 'Unknown Provider' },
            { label: 'Provider NPI (ID)', value: claim.providerId, accent: true },
            { label: 'Business Address', value: claim.providerAddress || 'Address Not Provided' },
          ].map(({ label, value, accent }) => (
            <div key={label}>
              <span
                style={{
                  fontSize: 10,
                  color: 'var(--text-tertiary)',
                  textTransform: 'uppercase',
                  fontFamily: 'var(--font-mono)',
                  display: 'block',
                  marginBottom: 4,
                }}
              >
                {label}
              </span>
              <span
                style={{
                  fontSize: 14,
                  fontWeight: 600,
                  fontFamily: 'var(--font-mono)',
                  color: accent ? 'var(--accent-primary)' : 'var(--text-primary)',
                }}
              >
                {value}
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* Billed Coding Details (CPT & ICD Table) */}
      <div className="card" style={{ padding: 20 }}>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            fontSize: 12,
            fontWeight: 700,
            fontFamily: 'var(--font-mono)',
            textTransform: 'uppercase',
            letterSpacing: '0.05em',
            color: 'var(--accent-primary)',
            marginBottom: 16,
          }}
        >
          <Shield size={14} /> Billed Procedure & Diagnosis Codes
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24 }}>
          {/* CPT Codes */}
          <div>
            <div
              style={{
                fontSize: 11,
                fontWeight: 700,
                color: 'var(--text-tertiary)',
                textTransform: 'uppercase',
                fontFamily: 'var(--font-mono)',
                marginBottom: 8,
              }}
            >
              Procedure Codes (CPT)
            </div>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ borderBottom: '1px solid var(--border-default)', textAlign: 'left' }}>
                  <th style={{ padding: '6px 8px', fontSize: 11, color: 'var(--text-tertiary)', fontFamily: 'var(--font-mono)' }}>
                    Code
                  </th>
                  <th style={{ padding: '6px 8px', fontSize: 11, color: 'var(--text-tertiary)', fontFamily: 'var(--font-mono)' }}>
                    Description
                  </th>
                  <th
                    style={{
                      padding: '6px 8px',
                      fontSize: 11,
                      color: 'var(--text-tertiary)',
                      fontFamily: 'var(--font-mono)',
                      textAlign: 'right',
                    }}
                  >
                    Status
                  </th>
                </tr>
              </thead>
              <tbody>
                {(claim.cptCodes || [claim.cptCode]).map((code, idx) => {
                  const status = getCptStatus(code);
                  return (
                    <tr key={code} style={{ borderBottom: '1px solid var(--border-default)', fontSize: 13 }}>
                      <td
                        style={{
                          padding: '8px',
                          fontWeight: 600,
                          fontFamily: 'var(--font-mono)',
                          color: 'var(--text-primary)',
                        }}
                      >
                        {code}
                      </td>
                      <td style={{ padding: '8px', color: 'var(--text-secondary)' }}>
                        {idx === 0 ? claim.cptCode : 'Billed Procedure'}
                      </td>
                      <td style={{ padding: '8px', textAlign: 'right' }}>
                        <span
                          style={{
                            fontSize: 10,
                            fontWeight: 700,
                            textTransform: 'uppercase',
                            fontFamily: 'var(--font-mono)',
                            padding: '2px 6px',
                            borderRadius: 4,
                            backgroundColor: `${status.color}15`,
                            color: status.color,
                            border: `1px solid ${status.color}30`,
                          }}
                        >
                          {status.label}
                        </span>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {/* ICD Codes */}
          <div>
            <div
              style={{
                fontSize: 11,
                fontWeight: 700,
                color: 'var(--text-tertiary)',
                textTransform: 'uppercase',
                fontFamily: 'var(--font-mono)',
                marginBottom: 8,
              }}
            >
              Diagnosis Codes (ICD-10)
            </div>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ borderBottom: '1px solid var(--border-default)', textAlign: 'left' }}>
                  <th style={{ padding: '6px 8px', fontSize: 11, color: 'var(--text-tertiary)', fontFamily: 'var(--font-mono)' }}>
                    Code
                  </th>
                  <th style={{ padding: '6px 8px', fontSize: 11, color: 'var(--text-tertiary)', fontFamily: 'var(--font-mono)' }}>
                    Description
                  </th>
                  <th
                    style={{
                      padding: '6px 8px',
                      fontSize: 11,
                      color: 'var(--text-tertiary)',
                      fontFamily: 'var(--font-mono)',
                      textAlign: 'right',
                    }}
                  >
                    Status
                  </th>
                </tr>
              </thead>
              <tbody>
                {(claim.icdCodes || [claim.icdCode]).map((code) => {
                  const status = getIcdStatus(code);
                  return (
                    <tr key={code} style={{ borderBottom: '1px solid var(--border-default)', fontSize: 13 }}>
                      <td
                        style={{
                          padding: '8px',
                          fontWeight: 600,
                          fontFamily: 'var(--font-mono)',
                          color: 'var(--text-primary)',
                        }}
                      >
                        {code}
                      </td>
                      <td style={{ padding: '8px', color: 'var(--text-secondary)' }}>ICD-10 Diagnostic Code</td>
                      <td style={{ padding: '8px', textAlign: 'right' }}>
                        <span
                          style={{
                            fontSize: 10,
                            fontWeight: 700,
                            textTransform: 'uppercase',
                            fontFamily: 'var(--font-mono)',
                            padding: '2px 6px',
                            borderRadius: 4,
                            backgroundColor: `${status.color}15`,
                            color: status.color,
                            border: `1px solid ${status.color}30`,
                          }}
                        >
                          {status.label}
                        </span>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {/* Source Clinical Notes Accordion */}
      {claim.linkedClinicalNotes?.length > 0 && (
        <div className="card" style={{ padding: 20 }}>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              fontSize: 12,
              fontWeight: 700,
              fontFamily: 'var(--font-mono)',
              textTransform: 'uppercase',
              letterSpacing: '0.05em',
              color: 'var(--accent-primary)',
              marginBottom: 16,
            }}
          >
            <HeartPulse size={14} /> Source Clinical Notes ({claim.linkedClinicalNotes.length})
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {claim.linkedClinicalNotes.map((note: string, i: number) => {
              let noteHeader = `Clinical Progress Note #${i + 1}`;
              let noteText = note;
              if (note.startsWith('[Date: ')) {
                const closingBracket = note.indexOf(']');
                if (closingBracket !== -1) {
                  const dateStr = note.substring(7, closingBracket);
                  noteHeader = `Clinical Progress Note — ${dateStr}`;
                  noteText = note.substring(closingBracket + 1).trim();
                }
              }
              const isExpanded = expandedNote === i;
              return (
                <div
                  key={i}
                  style={{
                    borderRadius: 6,
                    border: '1px solid var(--border-default)',
                    backgroundColor: 'var(--bg-body)',
                    overflow: 'hidden',
                  }}
                >
                  <button
                    onClick={() => setExpandedNote(isExpanded ? null : i)}
                    style={{
                      width: '100%',
                      padding: '12px 16px',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      background: 'var(--bg-card)',
                      border: 'none',
                      cursor: 'pointer',
                      textAlign: 'left',
                      color: 'var(--text-primary)',
                      fontFamily: 'var(--font-mono)',
                      fontSize: 12,
                      fontWeight: 600,
                    }}
                  >
                    <span>{noteHeader}</span>
                    <span style={{ fontSize: 10, color: 'var(--text-tertiary)' }}>
                      {isExpanded ? 'Collapse' : 'Expand'}
                    </span>
                  </button>
                  {isExpanded && (
                    <div
                      style={{
                        padding: 16,
                        fontSize: 13,
                        color: 'var(--text-secondary)',
                        lineHeight: 1.6,
                        borderTop: '1px solid var(--border-default)',
                        maxHeight: 250,
                        overflowY: 'auto',
                        whiteSpace: 'pre-wrap',
                        fontFamily: 'var(--font-sans)',
                      }}
                    >
                      {noteText}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Three-tier audit panels */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
        <h2
          style={{
            margin: 0,
            fontSize: 12,
            fontWeight: 700,
            color: 'var(--text-tertiary)',
            textTransform: 'uppercase',
            letterSpacing: '0.1em',
            fontFamily: 'var(--font-mono)',
          }}
        >
          Layered payment integrity findings
        </h2>
        {claim.tierResults && claim.tierResults.length > 0 ? (
          claim.tierResults.map((tier: AuditTierResult) => <TierPanel key={tier.tier} result={tier} />)
        ) : (
          <div
            style={{
              border: '1px dashed var(--border-default)',
              borderRadius: 8,
              padding: 20,
              textAlign: 'center',
              color: 'var(--text-tertiary)',
              fontFamily: 'var(--font-mono)',
              fontSize: 13,
            }}
          >
            <p style={{ margin: 0 }}>No tier data available</p>
            <p style={{ margin: '4px 0 0', fontSize: 11, color: 'var(--text-tertiary)' }}>
              {claim.disposition
                ? claim.disposition.includes('PYTHON EXCEPTION')
                  ? 'Python audit engine crashed — check AI agent logs and NVIDIA_API_KEY.'
                  : claim.disposition.includes('HOLD Notification')
                    ? 'Only basic HOLD notification found — full LLM adjudication was not generated.'
                    : 'Disposition exists but tier data could not be parsed. May need IRIS recompile.'
                : 'No disposition or tier data. The claim may have been ingested without AI auditing.'}
            </p>
            <button
              onClick={(e) => {
                e.stopPropagation();
                if (id) queryClient.invalidateQueries({ queryKey: ['claim', id] });
              }}
              style={{
                marginTop: 12,
                padding: '6px 16px',
                borderRadius: 6,
                border: '1px solid var(--border-default)',
                backgroundColor: 'transparent',
                color: 'var(--text-secondary)',
                cursor: 'pointer',
                fontSize: 12,
                fontFamily: 'var(--font-mono)',
              }}
            >
              Retry Load
            </button>
          </div>
        )}
      </div>

      {/* Full LLM report */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        <h2
          style={{
            margin: 0,
            fontSize: 12,
            fontWeight: 700,
            color: 'var(--text-tertiary)',
            textTransform: 'uppercase',
            letterSpacing: '0.1em',
            fontFamily: 'var(--font-mono)',
          }}
        >
          Explainable Adjudication justification
        </h2>
        {generatingReport || (claim.reportStatus === 'pending' && !generatedReportText) ? (
          <div
            className="card"
            style={{
              padding: 24,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 16,
              background: 'var(--accent-subtle)',
              border: '1px solid var(--border-focus)',
              borderRadius: 8,
              minHeight: 180,
              fontFamily: 'var(--font-mono)',
            }}
          >
            <RefreshCw size={28} className="animate-spin" style={{ color: 'var(--accent-primary)' }} />
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
              <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-primary)' }}>
                Generating explainable AI adjudication report...
              </div>
              <div style={{ fontSize: 11, color: 'var(--text-tertiary)' }}>
                This may take a few seconds as the model synthesizes patient note embeddings.
              </div>
            </div>
          </div>
        ) : (generatedReportText || claim.disposition) && !(generatedReportText || claim.disposition).includes('PYTHON EXCEPTION') ? (
          <DispositionReader markdown={generatedReportText || claim.disposition} />
        ) : (
          <div
            className="card"
            style={{ padding: 20, fontFamily: 'var(--font-mono)', fontSize: 13, color: 'var(--text-tertiary)' }}
          >
            Full LLM adjudication report not available. The Python agent could not connect to the LLM provider —
            verify your API key (<code style={{ color: 'var(--accent-text)' }}>NVIDIA_API_KEY</code>) in the{' '}
            <code style={{ color: 'var(--accent-text)' }}>.env</code> file and restart the container.
          </div>
        )}
      </div>

      {/* Role indicator */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 8,
          fontSize: 10,
          fontFamily: 'var(--font-mono)',
          borderRadius: 8,
          padding: '8px 12px',
          color: 'var(--text-tertiary)',
          border: '1px solid var(--border-default)',
        }}
      >
        <Shield size={12} />
        Signed in as{' '}
        <span style={{ fontWeight: 700, textTransform: 'uppercase', color: 'var(--text-primary)' }}>{activeRole}</span>
        {claim.escalated ? (
          <span style={{ marginLeft: 4, color: 'var(--color-warning)' }}>
            \u2014 escalated to director \u2022 task{' '}
            <span style={{ fontWeight: 700 }}>{claim.taskStatus || 'requested'}</span>
          </span>
        ) : claim.outcome === 'complete' ? (
          <span style={{ marginLeft: 4, color: 'var(--color-success)' }}>\u2014 approved</span>
        ) : claim.outcome === 'error' ? (
          <span style={{ marginLeft: 4, color: 'var(--color-danger)' }}>\u2014 rejected</span>
        ) : !canTakeAction ? (
          <span style={{ marginLeft: 4, color: 'var(--color-warning)' }}>
            \u2014 this role cannot take action on claims
          </span>
        ) : null}
      </div>

      {/* Decision actions */}
      {!isDecided && (
        <div style={{ display: 'flex', gap: 12, paddingTop: 16, borderTop: '1px solid var(--border-default)' }}>
          {PERMISSIONS.canApprove(activeRole) && (
            <button
              onClick={() => setModal('approve')}
              disabled={!userCanApprove}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 8,
                padding: '10px 20px',
                borderRadius: 8,
                fontSize: 14,
                fontWeight: 600,
                fontFamily: 'var(--font-mono)',
                cursor: userCanApprove ? 'pointer' : 'not-allowed',
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
                display: 'flex',
                alignItems: 'center',
                gap: 8,
                padding: '10px 20px',
                borderRadius: 8,
                fontSize: 14,
                fontWeight: 600,
                fontFamily: 'var(--font-mono)',
                cursor: userCanEscalate ? 'pointer' : 'not-allowed',
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
                display: 'flex',
                alignItems: 'center',
                gap: 8,
                padding: '10px 20px',
                borderRadius: 8,
                fontSize: 14,
                fontWeight: 600,
                fontFamily: 'var(--font-mono)',
                cursor: userCanReject ? 'pointer' : 'not-allowed',
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
      )}

      {PERMISSIONS.canReaudit(activeRole) && (
        <button
          onClick={handleReaudit}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            padding: '8px 16px',
            borderRadius: 8,
            fontSize: 13,
            fontWeight: 500,
            fontFamily: 'var(--font-mono)',
            cursor: 'pointer',
            backgroundColor: 'transparent',
            color: 'var(--text-secondary)',
            border: '1px solid var(--border-default)',
            marginTop: 12,
            width: 'fit-content',
          }}
        >
          <RefreshCw size={14} /> Re-run AI Audit
        </button>
      )}

      {modal && (
        <DecisionModal claimId={claim.id} action={modal} onConfirm={handleSuccess} onCancel={() => setModal(null)} />
      )}
    </div>
  );
}
