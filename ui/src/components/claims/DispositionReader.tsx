import ReactMarkdown from 'react-markdown';

export function DispositionReader({ markdown }: { markdown: string }) {
  if (!markdown) {
    return <p className="text-sm" style={{ color: 'var(--text-tertiary)' }}>No adjudication report available.</p>;
  }

  return (
    <div
      className="rounded-lg p-5 prose prose-sm max-w-none"
      style={{
        backgroundColor: 'var(--bg-card)',
        border: '1px solid var(--border-default)',
      }}
    >
      <div className="disposition-prose">
        <ReactMarkdown>{markdown}</ReactMarkdown>
      </div>
    </div>
  );
}
