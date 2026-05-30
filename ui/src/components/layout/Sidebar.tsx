import { NavLink } from 'react-router-dom';
import { LayoutDashboard, ShieldAlert, Network, MessageSquare, History } from 'lucide-react';
import { useChatStore } from '../../store/chatStore';

const navItems = [
  { to: '/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/queue',     icon: ShieldAlert,    label: 'Hold queue' },
  { to: '/graph',     icon: Network,        label: 'Network graph' },
  { to: '/ledger',    icon: History,        label: 'Audit ledger' },
];

export function Sidebar() {
  const { togglePanel, isOpen } = useChatStore();

  return (
    <aside className="w-16 bg-gray-900 border-r border-gray-800 flex flex-col items-center py-4 gap-2 shrink-0">
      {/* Logo */}
      <div className="w-10 h-10 flex items-center justify-center mb-4 overflow-hidden rounded-lg border border-gray-800 bg-gray-950 p-1 hover:border-gray-700 transition-colors">
        <img src="/logo.png" alt="ClaimAuditAI" className="w-full h-full object-contain" />
      </div>

      {navItems.map(({ to, icon: Icon, label }) => (
        <NavLink
          key={to}
          to={to}
          title={label}
          className={({ isActive }) =>
            `w-10 h-10 rounded-lg flex items-center justify-center transition-all ` +
            (isActive
              ? 'bg-red-600/20 text-red-400 border border-red-700/50'
              : 'text-gray-500 hover:text-gray-200 hover:bg-gray-800')
          }
        >
          <Icon size={20} />
        </NavLink>
      ))}

      <div className="flex-1" />

      {/* Platform badges */}
      <div className="flex flex-col items-center gap-1.5 mb-3">
        <span className="text-[8px] font-mono font-bold text-emerald-400 bg-emerald-500/10 border border-emerald-500/20 px-1.5 py-0.5 rounded leading-none" title="FHIR R4 Server Connected">
          FHIR
        </span>
        <span className="text-[8px] font-mono font-bold text-blue-400 bg-blue-500/10 border border-blue-500/20 px-1.5 py-0.5 rounded leading-none" title="InterSystems IRIS for Health">
          IRIS
        </span>
      </div>

      {/* Assistant */}
      <button
        onClick={togglePanel}
        title="AI audit assistant"
        className={`w-10 h-10 rounded-lg flex items-center justify-center transition-all ` +
          (isOpen
            ? 'bg-blue-600/20 text-blue-400 border border-blue-700/50'
            : 'text-gray-500 hover:text-gray-200 hover:bg-gray-800')
        }
      >
        <MessageSquare size={20} />
      </button>
    </aside>
  );
}