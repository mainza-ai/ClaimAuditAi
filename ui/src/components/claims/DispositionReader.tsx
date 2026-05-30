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
      <style>{`
        .disposition-prose h1, .disposition-prose h2, .disposition-prose h3,
        .disposition-prose h4, .disposition-prose h5, .disposition-prose h6 {
          color: var(--text-primary) !important;
        }
        .disposition-prose p {
          color: var(--text-secondary) !important;
        }
        .disposition-prose li {
          color: var(--text-secondary) !important;
        }
        .disposition-prose strong {
          color: var(--text-primary) !important;
        }
        .disposition-prose code {
          color: var(--accent-primary) !important;
          background-color: var(--bg-hover) !important;
        }
      `}</style>
      <div className="disposition-prose">
        <ReactMarkdown>{markdown}</ReactMarkdown>
      </div>
    </div>
  );
}
