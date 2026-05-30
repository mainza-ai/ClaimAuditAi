import { useState, type KeyboardEvent } from 'react';
import { Send } from 'lucide-react';

export function AssistantInput({
  onSend,
  disabled,
  placeholder,
}: {
  onSend: (text: string) => void;
  disabled: boolean;
  placeholder: string;
}) {
  const [value, setValue] = useState('');

  function handleSend() {
    if (value.trim() && !disabled) {
      onSend(value.trim());
      setValue('');
    }
  }

  function handleKey(e: KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  }

  return (
    <div className="flex items-end gap-2">
      <textarea
        value={value}
        onChange={(e) => setValue(e.target.value)}
        onKeyDown={handleKey}
        disabled={disabled}
        placeholder={placeholder}
        rows={1}
        className="flex-1 resize-none bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-200 placeholder-gray-600 focus:outline-none focus:border-blue-500 disabled:opacity-40 max-h-32 overflow-y-auto"
        style={{ minHeight: '38px' }}
      />
      <button
        onClick={handleSend}
        disabled={disabled || !value.trim()}
        className="p-2.5 bg-blue-600 hover:bg-blue-500 disabled:opacity-40 disabled:cursor-not-allowed text-white rounded-lg transition-colors shrink-0"
      >
        <Send size={16} />
      </button>
    </div>
  );
}