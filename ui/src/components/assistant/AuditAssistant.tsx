import { useRef, useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { useChatStore } from '../../store/chatStore';
import { streamChatMessage } from '../../api/chat';
import { getClaimDetail } from '../../api/claims';
import { MessageBubble } from './MessageBubble';
import { AssistantInput } from './AssistantInput';
import { X, Bot, RotateCcw } from 'lucide-react';
import type { ChatMessage, ClaimContext } from '../../types/chat';

export function AuditAssistant() {
  const location = useLocation();
  const isOpen = useChatStore((s) => s.isOpen);
  const togglePanel = useChatStore((s) => s.togglePanel);
  const getHistory = useChatStore((s) => s.getHistory);
  const addMessage = useChatStore((s) => s.addMessage);
  const syncMessage = useChatStore((s) => s.syncMessage);
  const fetchHistory = useChatStore((s) => s.fetchHistory);
  const setLoading = useChatStore((s) => s.setLoading);
  const isLoading = useChatStore((s) => s.isLoading);
  const clearHistory = useChatStore((s) => s.clearHistory);

  // In React Router, since AuditAssistant is rendered outside <Routes> in App.tsx, useParams() will be empty.
  // We parse the claim ID from location.pathname instead to have robust route context tracking.
  const pathMatch = location.pathname.match(/\/claims\/([^/]+)/);
  const routeClaimId = pathMatch ? pathMatch[1] : undefined;

  const effectiveClaimId = routeClaimId || 'global';
  const history = getHistory(effectiveClaimId);

  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Fetch claim detail to build context for the assistant
  const { data: rawClaim } = useQuery({
    queryKey: ['claim', effectiveClaimId],
    queryFn: () => getClaimDetail(effectiveClaimId!),
    enabled: !!effectiveClaimId && effectiveClaimId !== 'global',
  });

  const claim = rawClaim || null;

  const claimContext: ClaimContext | null = claim
    ? {
        claimId: claim.id,
        patientId: claim.patientId,
        cptCode: claim.cptCode,
        riskScore: claim.riskScore,
        dispositionSummary: claim.disposition ?? '',
        tierResults: claim.tierResults,
      }
    : null;

  useEffect(() => {
    if (isOpen && effectiveClaimId) {
      fetchHistory(effectiveClaimId);
    }
  }, [isOpen, effectiveClaimId, fetchHistory]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [history]);

  async function handleSend(text: string) {
    if (!text.trim() || isLoading || !effectiveClaimId) return;

    const userMsg: ChatMessage = {
      role: 'user',
      content: text.trim(),
      timestamp: new Date().toISOString(),
    };

    addMessage(effectiveClaimId, userMsg);
    syncMessage(effectiveClaimId, userMsg); // Sync user message immediately
    setLoading(true);

    // Add placeholder for streaming response
    const assistantPlaceholder: ChatMessage = {
      role: 'assistant',
      content: '',
      timestamp: new Date().toISOString(),
    };
    addMessage(effectiveClaimId, assistantPlaceholder);

    let fullContent = '';
    try {
      const updatedHistory = [...history, userMsg];

      for await (const chunk of streamChatMessage(updatedHistory, claimContext)) {
        fullContent += chunk;
        // Update the last assistant message with accumulated content
        const histories = useChatStore.getState().histories;
        const current = [...(histories[effectiveClaimId] || [])];
        if (current.length > 0) {
          current[current.length - 1] = { ...current[current.length - 1], content: fullContent };
          useChatStore.setState({ histories: { ...histories, [effectiveClaimId]: current } });
        }
      }

      // Sync final response to server
      const finalAssistantMsg: ChatMessage = {
        role: 'assistant',
        content: fullContent,
        timestamp: new Date().toISOString(),
      };
      syncMessage(effectiveClaimId, finalAssistantMsg);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Connection error';
      const histories = useChatStore.getState().histories;
      const current = [...(histories[effectiveClaimId] || [])];
      const errorMsgContent = message
        ? `Error: ${message}`
        : 'Sorry, I encountered an error reaching the LLM provider.';
      if (current.length > 0) {
        current[current.length - 1] = {
          ...current[current.length - 1],
          content: errorMsgContent,
        };
        useChatStore.setState({ histories: { ...histories, [effectiveClaimId]: current } });
      }

      // Sync error response to server as well so it persists
      const finalErrorMsg: ChatMessage = {
        role: 'assistant',
        content: errorMsgContent,
        timestamp: new Date().toISOString(),
      };
      syncMessage(effectiveClaimId, finalErrorMsg);
    } finally {
      setLoading(false);
    }
  }

  if (!isOpen) return null;

  return (
    <div
      style={{
        position: 'fixed',
        top: 0,
        right: 0,
        height: '100vh',
        width: 384,
        backgroundColor: 'var(--bg-card)',
        borderLeft: '1px solid var(--border-default)',
        display: 'flex',
        flexDirection: 'column',
        zIndex: 40,
        boxShadow: 'var(--shadow-modal)',
      }}
    >
      {/* Header */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '12px 16px',
          borderBottom: '1px solid var(--border-default)',
          flexShrink: 0,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Bot size={18} style={{ color: 'var(--accent-primary)' }} />
          <span style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-primary)' }}>Audit Assistant</span>
          {effectiveClaimId && effectiveClaimId !== 'global' && (
            <span style={{ fontSize: 12, color: 'var(--text-tertiary)', fontFamily: 'var(--font-mono)' }}>
              · {effectiveClaimId}
            </span>
          )}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          {effectiveClaimId && history.length > 0 && (
            <button
              onClick={() => clearHistory(effectiveClaimId)}
              title="Clear conversation"
              style={{
                padding: '6px',
                borderRadius: 4,
                background: 'none',
                border: 'none',
                color: 'var(--text-tertiary)',
                cursor: 'pointer',
              }}
            >
              <RotateCcw size={14} />
            </button>
          )}
          <button
            onClick={togglePanel}
            style={{
              padding: '6px',
              borderRadius: 4,
              background: 'none',
              border: 'none',
              color: 'var(--text-tertiary)',
              cursor: 'pointer',
            }}
          >
            <X size={16} />
          </button>
        </div>
      </div>

      {/* Context pill */}
      {claimContext && effectiveClaimId !== 'global' ? (
        <div
          style={{
            padding: '8px 16px',
            backgroundColor: 'var(--bg-page)',
            borderBottom: '1px solid var(--border-default)',
            flexShrink: 0,
          }}
        >
          <p style={{ fontSize: 12, color: 'var(--text-tertiary)' }}>
            Reviewing claim{' '}
            <span style={{ color: 'var(--accent-primary)', fontFamily: 'var(--font-mono)', fontWeight: 700 }}>
              {claimContext.claimId}
            </span>
            {' · '}CPT <span style={{ color: 'var(--text-primary)', fontWeight: 700 }}>{claimContext.cptCode}</span>
            {' · '}Risk{' '}
            <span style={{ color: 'var(--color-danger)', fontFamily: 'var(--font-mono)', fontWeight: 700 }}>
              {Number(claimContext.riskScore ?? 0).toFixed(2)}
            </span>
          </p>
        </div>
      ) : (
        <div
          style={{
            padding: '8px 16px',
            backgroundColor: 'var(--bg-page)',
            borderBottom: '1px solid var(--border-default)',
            flexShrink: 0,
          }}
        >
          <p
            style={{
              fontSize: 12,
              color: 'var(--text-tertiary)',
              fontFamily: 'var(--font-mono)',
              display: 'flex',
              alignItems: 'center',
              gap: 6,
            }}
          >
            <span className="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse" />
            Mode: <span style={{ color: 'var(--accent-primary)', fontWeight: 700 }}>General integrity Advisor</span>
          </p>
        </div>
      )}

      {/* Messages */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 16px' }}>
        {history.length === 0 && (
          <div style={{ marginTop: 16 }}>
            <p style={{ fontSize: 12, color: 'var(--text-tertiary)', textAlign: 'center' }}>Suggested questions:</p>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 12 }}>
              {(effectiveClaimId !== 'global'
                ? [
                    'Why was this claim flagged?',
                    'Explain the Tier 1 semantic mismatch in plain English.',
                    'What does CPT 99291 mean and is it appropriate here?',
                    'Could this be a false positive?',
                    'What action do you recommend?',
                  ]
                : [
                    'What is pre-payment claims integrity?',
                    'How does the vector clinical auditing tier work?',
                    'What is the reconstruction loss threshold for the autoencoder?',
                    'How does Cytoscape collusion network cycles detection work?',
                    'Explain InterSystems IRIS for Health and Embedded Python.',
                  ]
              ).map((q) => (
                <button
                  key={q}
                  onClick={() => handleSend(q)}
                  style={{
                    width: '100%',
                    textAlign: 'left',
                    fontSize: 12,
                    color: 'var(--accent-text)',
                    padding: '8px 12px',
                    backgroundColor: 'var(--accent-subtle)',
                    borderRadius: 8,
                    border: '1px solid var(--border-focus)',
                    cursor: 'pointer',
                    fontFamily: 'var(--font-mono)',
                  }}
                >
                  {q}
                </button>
              ))}
            </div>
          </div>
        )}

        {history.map((msg, i) => (
          <MessageBubble key={i} message={msg} />
        ))}

        {isLoading && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: 'var(--text-tertiary)', marginTop: 8 }}>
            <span className="w-1.5 h-1.5 bg-gray-500 rounded-full animate-bounce [animation-delay:0ms]" />
            <span className="w-1.5 h-1.5 bg-gray-500 rounded-full animate-bounce [animation-delay:150ms]" />
            <span className="w-1.5 h-1.5 bg-gray-500 rounded-full animate-bounce [animation-delay:300ms]" />
            <span style={{ fontSize: 12, fontFamily: 'var(--font-mono)' }}>Thinking...</span>
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>

      {/* Quick Prompt Chips */}
      {effectiveClaimId && (
        <div
          style={{
            borderTop: '1px solid var(--border-default)',
            padding: '8px 16px',
            backgroundColor: 'var(--bg-page)',
            display: 'flex',
            flexWrap: 'wrap',
            gap: 6,
            flexShrink: 0,
          }}
        >
          {(effectiveClaimId !== 'global'
            ? [
                {
                  label: 'Summarize Anomaly',
                  prompt: 'Summarize why this claim was flagged by the three-tier system.',
                },
                {
                  label: 'Verify CPT Guidelines',
                  prompt: 'Verify if the billed CPT code matches standard clinical guidelines for this patient.',
                },
                {
                  label: 'Draft Appeal Rejection',
                  prompt: 'Draft a formal provider appeal rejection letter citing all anomalies found.',
                },
              ]
            : [
                {
                  label: 'Pre-Payment Integrity',
                  prompt:
                    'Explain the paradigm shift from retroactive pay-and-chase audits to real-time pre-payment integrity.',
                },
                {
                  label: 'Embedded Python Tiers',
                  prompt: 'Explain the three AI auditing tiers running inside the InterSystems IRIS database kernel.',
                },
                {
                  label: 'Contest Goals',
                  prompt: 'Summarize how ClaimAuditAI maximizes bonus points for the InterSystems AI Agents contest.',
                },
              ]
          ).map((chip) => (
            <button
              key={chip.label}
              disabled={isLoading}
              onClick={() => handleSend(chip.prompt)}
              style={{
                fontSize: 10,
                fontFamily: 'var(--font-mono)',
                fontWeight: 700,
                backgroundColor: 'var(--bg-card)',
                border: '1px solid var(--border-default)',
                color: 'var(--text-secondary)',
                padding: '4px 8px',
                borderRadius: 4,
                cursor: 'pointer',
              }}
            >
              {chip.label}
            </button>
          ))}
        </div>
      )}

      {/* Input */}
      <div
        style={{
          borderTop: '1px solid var(--border-default)',
          padding: '12px 16px',
          backgroundColor: 'var(--bg-card)',
          flexShrink: 0,
        }}
      >
        <AssistantInput
          onSend={handleSend}
          disabled={isLoading}
          placeholder={
            effectiveClaimId !== 'global' ? 'Ask about this claim...' : 'Ask a general payor-integrity question...'
          }
        />
      </div>
    </div>
  );
}
