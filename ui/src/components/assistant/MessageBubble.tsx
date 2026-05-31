import ReactMarkdown from 'react-markdown';
import type { ChatMessage } from '../../types/chat';

export function MessageBubble({ message }: { message: ChatMessage }) {
  const isUser = message.role === 'user';

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
            <ReactMarkdown>{message.content}</ReactMarkdown>
          </div>
        )}
      </div>
    </div>
  );
}
