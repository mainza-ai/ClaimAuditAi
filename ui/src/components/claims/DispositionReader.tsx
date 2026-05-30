import ReactMarkdown from 'react-markdown';

export function DispositionReader({ markdown }: { markdown: string }) {
  if (!markdown) {
    return <p className="text-gray-500 text-sm">No adjudication report available.</p>;
  }

  return (
    <div className="bg-gray-900 border border-gray-800 rounded-lg p-5 prose prose-invert prose-sm max-w-none
      prose-headings:text-gray-200 prose-headings:font-medium prose-headings:mb-3
      prose-p:text-gray-400 prose-p:leading-relaxed prose-p:mb-4
      prose-li:text-gray-400
      prose-strong:text-gray-200
      prose-code:text-blue-300 prose-code:bg-gray-800 prose-code:px-1 prose-code:rounded">
      <ReactMarkdown>{markdown}</ReactMarkdown>
    </div>
  );
}