import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { approveClaim, escalateClaim, rejectClaim } from '../../api/claims';
import { apiClient } from '../../api/client';
import { useUserStore } from '../../store/userStore';
import { X, Loader2, CheckCircle } from 'lucide-react';

type ActionType = 'approve' | 'escalate' | 'reject';

interface DecisionModalProps {
  claimId: string;
  action: ActionType;
  onConfirm: () => void;
  onCancel: () => void;
}

const ACTION_CONFIG = {
  approve: {
    title: 'Approve Claim',
    label: 'Approval rationale',
    placeholder: 'State your clinical and financial rationale for approving this claim...',
    confirmLabel: 'Confirm Approval',
    confirmStyle: { backgroundColor: 'var(--color-success)' },
  },
  escalate: {
    title: 'Escalate to Director Review',
    label: 'Escalation reason',
    placeholder: 'Describe why this claim requires director-level review...',
    confirmLabel: 'Escalate',
    confirmStyle: { backgroundColor: 'var(--color-warning)' },
  },
  reject: {
    title: 'Reject Claim',
    label: 'Rejection reason',
    placeholder: 'Provide the specific clinical or compliance basis for rejection...',
    confirmLabel: 'Confirm Rejection',
    confirmStyle: { backgroundColor: 'var(--color-danger)' },
  },
};

export function DecisionModal({ claimId, action, onConfirm, onCancel }: DecisionModalProps) {
  const { name: authorizedBy } = useUserStore();
  const config = ACTION_CONFIG[action];
  const [rawReason, setRawReason] = useState('');
  const [aiSummary, setAiSummary] = useState('');
  const [summarizing, setSummarizing] = useState(false);
  const [summaryReady, setSummaryReady] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  const submit = useMutation({
    mutationFn: () => {
      const body = { authorizedBy, rationaleSummary: summaryReady ? aiSummary : rawReason };
      if (action === 'approve') return approveClaim(claimId, body);
      if (action === 'escalate') return escalateClaim(claimId, body);
      return rejectClaim(claimId, body);
    },
    onSuccess: onConfirm,
    onError: (err: any) => {
      setSubmitError(err?.response?.data?.error || err?.message || 'Submission failed');
    },
  });

  async function handleSummarize() {
    if (!rawReason.trim()) return;
    setSummarizing(true);
    try {
      const res = await apiClient.post('/claims/summarize-rationale', {
        action,
        userText: rawReason,
      });
      setAiSummary(res.data.summary || rawReason);
      setSummaryReady(true);
    } catch {
      setAiSummary(rawReason);
      setSummaryReady(true);
    } finally {
      setSummarizing(false);
    }
  }

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        backgroundColor: 'rgba(0,0,0,0.5)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 100,
      }}
    >
      <div
        className="card"
        style={{ width: 540, maxWidth: '90vw', padding: 24, display: 'flex', flexDirection: 'column', gap: 20 }}
      >
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <h2 style={{ margin: 0, fontSize: 18, fontWeight: 600, color: 'var(--text-primary)' }}>
            {config.title}
          </h2>
          <button
            onClick={onCancel}
            style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-tertiary)' }}
          >
            <X size={20} />
          </button>
        </div>

        <div style={{ fontSize: 13, color: 'var(--text-secondary)' }}>
          Action performed by:{' '}
          <strong style={{ color: 'var(--text-primary)' }}>
            {authorizedBy || 'Unknown user'}
          </strong>
        </div>

        <div>
          <label style={{ fontSize: 13, fontWeight: 500, color: 'var(--text-secondary)', display: 'block', marginBottom: 6 }}>
            {config.label} <span style={{ color: 'var(--color-danger)' }}>*</span>
          </label>
          <textarea
            value={rawReason}
            onChange={e => { setRawReason(e.target.value); }}
            placeholder={config.placeholder}
            rows={4}
            style={{
              width: '100%',
              resize: 'vertical',
              backgroundColor: 'var(--bg-input)',
              border: '1px solid var(--border-default)',
              color: 'var(--text-primary)',
              borderRadius: 6,
              padding: '10px 12px',
              fontSize: 13,
              fontFamily: 'var(--font-body)',
              outline: 'none',
              boxSizing: 'border-box',
            }}
          />
        </div>

        {!summaryReady && rawReason.trim().length > 10 && (
          <button
            onClick={handleSummarize}
            disabled={summarizing}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              padding: '8px 16px',
              backgroundColor: 'var(--accent-subtle)',
              border: '1px solid var(--accent-primary)',
              borderRadius: 6,
              color: 'var(--accent-text)',
              fontSize: 13,
              fontWeight: 500,
              cursor: 'pointer',
              width: 'fit-content',
            }}
          >
            {summarizing ? <Loader2 size={14} className="animate-spin" /> : null}
            {summarizing ? 'Generating AI summary...' : 'Generate AI rationale summary (optional)'}
          </button>
        )}

        {summaryReady && (
          <div
            style={{
              backgroundColor: 'var(--bg-page)',
              border: '1px solid var(--border-default)',
              borderRadius: 6,
              padding: 14,
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 8 }}>
              <CheckCircle size={14} color="var(--color-success)" />
              <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.06em' }}>
                AI-Generated Rationale (Audit Ledger Entry)
              </span>
            </div>
            <textarea
              value={aiSummary}
              onChange={e => setAiSummary(e.target.value)}
              rows={3}
              style={{
                width: '100%',
                resize: 'vertical',
                backgroundColor: 'transparent',
                border: 'none',
                color: 'var(--text-primary)',
                fontSize: 13,
                fontFamily: 'var(--font-body)',
                outline: 'none',
                boxSizing: 'border-box',
              }}
            />
            <p style={{ margin: '6px 0 0', fontSize: 11, color: 'var(--text-tertiary)' }}>
              You may edit this before submitting. This text will appear in the audit ledger.
            </p>
          </div>
        )}

        {submitError && (
          <div style={{ padding: 10, borderRadius: 6, backgroundColor: 'var(--color-danger-bg)', border: '1px solid var(--color-danger-border)' }}>
            <p style={{ margin: 0, fontSize: 13, color: 'var(--color-danger)' }}>{submitError}</p>
          </div>
        )}

        <div style={{ display: 'flex', gap: 12, justifyContent: 'flex-end' }}>
          <button onClick={onCancel} className="btn-ghost">Cancel</button>
          <button
            onClick={() => submit.mutate()}
            disabled={submit.isPending || !rawReason.trim()}
            className="btn-primary"
            style={{ ...config.confirmStyle, opacity: !rawReason.trim() ? 0.5 : 1 }}
          >
            {submit.isPending ? 'Submitting...' : config.confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
