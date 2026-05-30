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
  const [inputFocused, setInputFocused] = useState(false);
  const [inputHovered, setInputHovered] = useState(false);
  const [btnHovered, setBtnHovered] = useState(false);

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
        className="flex-1 resize-none rounded-lg px-3 py-2 text-sm max-h-32 overflow-y-auto disabled:opacity-40 focus:outline-none"
        style={{
          backgroundColor: 'var(--bg-input)',
          border: inputFocused ? '1px solid var(--border-focus)' : (inputHovered ? '1px solid var(--border-strong)' : '1px solid var(--border-default)'),
          color: 'var(--text-primary)',
          minHeight: '38px',
        }}
        onFocus={() => setInputFocused(true)}
        onBlur={() => setInputFocused(false)}
        onMouseEnter={() => setInputHovered(true)}
        onMouseLeave={() => setInputHovered(false)}
      />
      <button
        onClick={handleSend}
        disabled={disabled || !value.trim()}
        className="p-2.5 rounded-lg transition-colors shrink-0 disabled:opacity-40 disabled:cursor-not-allowed"
        style={{
          backgroundColor: btnHovered && !disabled && value.trim() ? 'var(--accent-hover)' : 'var(--accent-primary)',
          color: 'var(--text-inverse)',
        }}
        onMouseEnter={() => setBtnHovered(true)}
        onMouseLeave={() => setBtnHovered(false)}
      >
        <Send size={16} />
      </button>
    </div>
  );
}
