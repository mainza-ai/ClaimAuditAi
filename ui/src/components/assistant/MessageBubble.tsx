import { useState } from 'react';
import ReactMarkdown from 'react-markdown';
import type { ChatMessage } from '../../types/chat';
import { Copy, Check } from 'lucide-react';

export function MessageBubble({ message }: { message: ChatMessage }) {
  const isUser = message.role === 'user';
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    await navigator.clipboard.writeText(message.content);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="flex" style={{ justifyContent: isUser ? 'flex-end' : 'flex-start' }}>
      <div
        className="max-w-[85%] rounded-xl px-3 py-2 text-sm leading-relaxed border prose prose-sm max-w-none prose-p:my-1 prose-code:px-1 prose-code:rounded"
        style={{
          backgroundColor: isUser ? 'var(--accent-subtle)' : 'var(--bg-card)',
          color: isUser ? 'var(--accent-primary)' : 'var(--text-primary)',
          borderColor: isUser ? 'var(--border-focus)' : 'var(--border-default)',
          borderRadius: isUser ? '0.75rem 0.75rem 0.125rem 0.75rem' : '0.75rem 0.75rem 0.75rem 0.125rem',
        }}
      >
        {isUser ? (
          message.content
        ) : (
          <div className="message-bubble-assistant">
            <ReactMarkdown>{message.content || '\u200b'}</ReactMarkdown>
          </div>
        )}
      </div>

      {!isUser && message.content && (
        <button
          onClick={handleCopy}
          title="Copy to clipboard"
          style={{
            background: 'none',
            border: 'none',
            cursor: 'pointer',
            color: copied ? 'var(--color-success)' : 'var(--text-tertiary)',
            padding: '4px',
            marginLeft: 4,
            fontSize: 12,
            alignSelf: 'flex-start',
            marginTop: 4,
          }}
        >
          {copied ? <Check size={14} /> : <Copy size={14} />}
        </button>
      )}
    </div>
  );
}
