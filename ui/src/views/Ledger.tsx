import { useQuery } from '@tanstack/react-query';
import { getLedger } from '../api/ledger';
import { ShieldCheck, AlertTriangle, UserCheck, Clock } from 'lucide-react';
import { format } from 'date-fns';

export function Ledger() {
const { data: entries = [], isLoading } = useQuery({
queryKey: ['ledger'],
queryFn: getLedger,
});

return (
<div className="space-y-6">
<div className="flex items-center justify-between border-b border-gray-800 pb-4">
<div>
<h1 className="text-xl font-bold text-gray-100 tracking-wider">Override Audit Ledger</h1>
<p className="text-xs text-gray-500 font-mono mt-1">
System transaction logs and manual adjudication override records
</p>
</div>
<div className="flex items-center gap-2 text-xs font-mono px-3 py-1.5 bg-gray-900 border border-gray-800 rounded text-gray-400">
<ShieldCheck size={14} className="text-green-400 animate-pulse" />
Tamper-Proof Ledger Active
</div>
</div>

<div className="bg-gray-900 border border-gray-800 rounded-lg overflow-hidden">
{isLoading ? (
<div className="text-gray-500 text-sm py-12 text-center font-mono">Loading ledger...</div>
) : entries.length === 0 ? (
<div className="text-gray-500 text-sm py-12 text-center border border-dashed border-gray-800 rounded-lg m-4">
No override records yet. Approve or escalate held claims to populate the audit ledger.
</div>
) : (
<table className="w-full text-left font-mono border-collapse">
<thead>
<tr className="bg-gray-950 text-gray-500 text-xs border-b border-gray-800 uppercase tracking-wider">
<th className="px-5 py-3.5 font-semibold">Tx ID</th>
<th className="px-5 py-3.5 font-semibold">Claim ID</th>
<th className="px-5 py-3.5 font-semibold">Type</th>
<th className="px-5 py-3.5 font-semibold">Billed</th>
<th className="px-5 py-3.5 font-semibold">Authorizer</th>
<th className="px-5 py-3.5 font-semibold">Timestamp</th>
<th className="px-5 py-3.5 font-semibold">Rationale / Override Note</th>
</tr>
</thead>
<tbody className="divide-y divide-gray-800 text-sm text-gray-300">
{entries.map((entry) => (
<tr key={entry.id} className="hover:bg-gray-800/40 transition-colors">
<td className="px-5 py-4 font-semibold text-gray-400">{entry.id}</td>
<td className="px-5 py-4 font-semibold text-blue-400">#{entry.claimId}</td>
<td className="px-5 py-4">
<span className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded text-xs border uppercase tracking-wide font-semibold ` +
(entry.action === 'approved'
? 'bg-green-500/10 text-green-400 border-green-500/20'
: 'bg-yellow-500/10 text-yellow-400 border-yellow-500/20')
}>
{entry.action === 'approved' ? <UserCheck size={12} /> : <AlertTriangle size={12} />}
{entry.action}
</span>
</td>
<td className="px-5 py-4 font-semibold text-gray-200">
${entry.amount.toLocaleString()}
</td>
<td className="px-5 py-4 text-xs text-gray-400">{entry.authorizedBy}</td>
<td className="px-5 py-4 text-xs text-gray-500 flex items-center gap-1.5 pt-5">
<Clock size={12} />
{format(new Date(entry.timestamp), 'yyyy-MM-dd HH:mm:ss')}
</td>
<td className="px-5 py-4 text-xs text-gray-400 leading-relaxed max-w-sm whitespace-normal break-words font-sans">
{entry.reason}
</td>
</tr>
))}
</tbody>
</table>
)}
</div>
</div>
);
}
