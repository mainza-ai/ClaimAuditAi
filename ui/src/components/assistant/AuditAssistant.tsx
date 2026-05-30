import { useRef, useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { useChatStore } from '../../store/chatStore';
import { sendChatMessage } from '../../api/chat';
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
        dispositionSummary: claim.disposition?.slice(0, 500) ?? '',
        tier1Summary: claim.tierResults?.find((t) => t.tier === 1)?.summary ?? '',
        tier2Loss: claim.tierResults?.find((t) => t.tier === 2)?.score ?? 0,
        tier2Threshold: claim.tierResults?.find((t) => t.tier === 2)?.threshold ?? 0,
        tier3Flags: claim.tierResults?.find((t) => t.tier === 3)?.flags ?? [],
      }
    : null;

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
    setLoading(true);

    try {
      const updatedHistory = [...history, userMsg];
      const response = await sendChatMessage(updatedHistory, claimContext);

      addMessage(effectiveClaimId, {
        role: 'assistant',
        content: response,
        timestamp: new Date().toISOString(),
      });
} catch (err) {
const message = err instanceof Error ? err.message : '';
addMessage(effectiveClaimId, {
role: 'assistant',
content: message
? `Error: ${message}`
: 'Sorry, I encountered an error reaching the LLM provider. Check your .env configuration.',
timestamp: new Date().toISOString(),
});
    } finally {
      setLoading(false);
    }
  }

  if (!isOpen) return null;

  return (
    <div className="fixed top-0 right-0 h-full w-96 bg-gray-900 border-l border-gray-800 flex flex-col z-40 shadow-2xl">
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 border-b border-gray-800 shrink-0">
        <div className="flex items-center gap-2">
          <Bot size={18} className="text-blue-400" />
          <span className="text-sm font-semibold text-gray-200">Audit Assistant</span>
          {effectiveClaimId && effectiveClaimId !== 'global' && (
            <span className="text-xs text-gray-500 font-mono">· {effectiveClaimId}</span>
          )}
        </div>
        <div className="flex items-center gap-2">
          {effectiveClaimId && history.length > 0 && (
            <button
              onClick={() => clearHistory(effectiveClaimId)}
              title="Clear conversation"
              className="p-1.5 rounded text-gray-500 hover:text-gray-300 hover:bg-gray-800 transition-colors"
            >
              <RotateCcw size={14} />
            </button>
          )}
          <button
            onClick={togglePanel}
            className="p-1.5 rounded text-gray-500 hover:text-gray-300 hover:bg-gray-800 transition-colors"
          >
            <X size={16} />
          </button>
        </div>
      </div>

      {/* Context pill */}
      {claimContext && effectiveClaimId !== 'global' ? (
        <div className="px-4 py-2 bg-gray-950/30 border-b border-gray-800/50 shrink-0">
          <p className="text-xs text-gray-500">
            Reviewing claim <span className="text-blue-400 font-mono font-bold">{claimContext.claimId}</span>
            {' · '}CPT <span className="text-gray-300 font-bold">{claimContext.cptCode?.slice(0, 15)}...</span>
            {' · '}Risk <span className="text-red-400 font-mono font-bold">{claimContext.riskScore.toFixed(2)}</span>
          </p>
        </div>
      ) : (
        <div className="px-4 py-2 bg-gray-950/30 border-b border-gray-800/50 shrink-0">
          <p className="text-xs text-gray-500 font-mono flex items-center gap-1.5">
            <span className="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse" />
            Mode: <span className="text-blue-400 font-bold">General integrity Advisor</span>
          </p>
        </div>
      )}

      {/* Messages */}
      <div className="flex-1 overflow-y-auto px-4 py-4 space-y-4">
        {history.length === 0 && (
          <div className="space-y-2 mt-4">
            <p className="text-xs text-gray-500 text-center">Suggested questions:</p>
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
                className="w-full text-left text-xs text-blue-400 hover:text-blue-300 px-3 py-2 bg-blue-950/30 rounded-lg border border-blue-900/50 hover:border-blue-700 transition-all font-mono"
              >
                {q}
              </button>
            ))}
          </div>
        )}

        {history.map((msg, i) => (
          <MessageBubble key={i} message={msg} />
        ))}

        {isLoading && (
          <div className="flex items-center gap-2 text-gray-500 mt-2">
            <div className="flex gap-1">
              <span className="w-1.5 h-1.5 bg-gray-500 rounded-full animate-bounce [animation-delay:0ms]" />
              <span className="w-1.5 h-1.5 bg-gray-500 rounded-full animate-bounce [animation-delay:150ms]" />
              <span className="w-1.5 h-1.5 bg-gray-500 rounded-full animate-bounce [animation-delay:300ms]" />
            </div>
            <span className="text-xs font-mono">Thinking...</span>
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>

      {/* Quick Prompt Chips */}
      {effectiveClaimId && (
        <div className="border-t border-gray-800/60 px-4 py-2 bg-gray-950/20 flex flex-wrap gap-1.5 shrink-0">
          {(effectiveClaimId !== 'global'
            ? [
                { label: 'Summarize Anomaly', prompt: 'Summarize why this claim was flagged by the three-tier system.' },
                { label: 'Verify CPT Guidelines', prompt: 'Verify if the billed CPT code matches standard clinical guidelines for this patient.' },
                { label: 'Draft Appeal Rejection', prompt: 'Draft a formal provider appeal rejection letter citing all anomalies found.' },
              ]
            : [
                { label: 'Pre-Payment Integrity', prompt: 'Explain the paradigm shift from retroactive pay-and-chase audits to real-time pre-payment integrity.' },
                { label: 'Embedded Python Tiers', prompt: 'Explain the three AI auditing tiers running inside the InterSystems IRIS database kernel.' },
                { label: 'Contest Goals', prompt: 'Summarize how ClaimAuditAI maximizes bonus points for the InterSystems AI Agents contest.' },
              ]
          ).map((chip) => (
            <button
              key={chip.label}
              disabled={isLoading}
              onClick={() => handleSend(chip.prompt)}
              className="text-[10px] font-mono font-bold bg-gray-800 hover:bg-gray-700/80 border border-gray-700/60 hover:border-blue-500/40 text-gray-300 hover:text-blue-400 px-2 py-1 rounded transition-all disabled:opacity-40"
            >
              {chip.label}
            </button>
          ))}
        </div>
      )}

      {/* Input */}
      <div className="border-t border-gray-800 px-4 py-3 bg-gray-900 shrink-0">
        <AssistantInput
          onSend={handleSend}
          disabled={isLoading}
          placeholder={
            effectiveClaimId !== 'global'
              ? 'Ask about this claim...'
              : 'Ask a general payor-integrity question...'
          }
        />
      </div>
    </div>
  );
}