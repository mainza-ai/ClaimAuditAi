import ReactMarkdown from 'react-markdown';
import type { ChatMessage } from '../../types/chat';
import clsx from 'clsx';

export function MessageBubble({ message }: { message: ChatMessage }) {
  const isUser = message.role === 'user';

  return (
    <div className={clsx('flex', isUser ? 'justify-end' : 'justify-start')}>
      <div
        className={clsx(
          'max-w-[85%] rounded-xl px-3 py-2 text-sm leading-relaxed border',
          isUser
            ? 'bg-blue-600/10 text-blue-200 border-blue-800/50 rounded-br-sm'
            : 'bg-gray-800 border-gray-700 text-gray-200 rounded-bl-sm prose prose-invert prose-sm max-w-none prose-p:my-1 prose-code:text-blue-300 prose-code:bg-gray-700 prose-code:px-1 prose-code:rounded'
        )}
      >
        {isUser ? (
          message.content
        ) : (
          <ReactMarkdown>{message.content}</ReactMarkdown>
        )}
      </div>
    </div>
  );
}