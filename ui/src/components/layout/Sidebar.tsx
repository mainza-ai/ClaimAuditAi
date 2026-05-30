import { NavLink } from 'react-router-dom';
import { LayoutDashboard, ShieldAlert, Network, MessageSquare, History } from 'lucide-react';
import { useState } from 'react';
import { useChatStore } from '../../store/chatStore';

const navItems = [
  { to: '/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/queue',     icon: ShieldAlert,    label: 'Hold queue' },
  { to: '/graph',     icon: Network,        label: 'Network graph' },
  { to: '/ledger',    icon: History,        label: 'Audit ledger' },
];

export function Sidebar() {
  const togglePanel = useChatStore((s) => s.togglePanel);
  const isOpen = useChatStore((s) => s.isOpen);
  const [logoHovered, setLogoHovered] = useState(false);

  return (
    <aside
      className="w-16 flex flex-col items-center py-4 gap-2 shrink-0"
      style={{ backgroundColor: 'var(--bg-sidebar)', borderRight: '1px solid var(--border-default)' }}
    >
      {/* Logo */}
      <div
        className="w-10 h-10 flex items-center justify-center mb-4 overflow-hidden rounded-lg p-1 transition-colors"
        style={{
          backgroundColor: 'var(--bg-page)',
          border: logoHovered ? '1px solid var(--border-strong)' : '1px solid var(--border-default)',
        }}
        onMouseEnter={() => setLogoHovered(true)}
        onMouseLeave={() => setLogoHovered(false)}
      >
        <img src="/logo.png" alt="ClaimAuditAI" className="w-full h-full object-contain" />
      </div>

      {navItems.map(({ to, icon: Icon, label }) => (
        <NavLink
          key={to}
          to={to}
          title={label}
          className="w-10 h-10 rounded-lg flex items-center justify-center transition-all"
          style={({ isActive }) => ({
            backgroundColor: isActive ? 'var(--bg-active-nav)' : 'transparent',
            color: isActive ? 'var(--accent-text)' : 'var(--text-tertiary)',
            border: isActive ? '1px solid var(--accent-primary)' : '1px solid transparent',
          })}
        >
          <Icon size={20} />
        </NavLink>
      ))}

      <div className="flex-1" />

      {/* Platform badges */}
      <div className="flex flex-col items-center gap-1.5 mb-3">
        <span
          className="text-[8px] font-mono font-bold px-1.5 py-0.5 rounded leading-none"
          style={{
            color: 'var(--color-success)',
            backgroundColor: 'var(--color-success-bg)',
            border: '1px solid var(--color-success-border)',
          }}
          title="FHIR R4 Server Connected"
        >
          FHIR
        </span>
        <span
          className="text-[8px] font-mono font-bold px-1.5 py-0.5 rounded leading-none"
          style={{
            color: 'var(--accent-primary)',
            backgroundColor: 'var(--accent-subtle)',
            border: '1px solid var(--border-focus)',
          }}
          title="InterSystems IRIS for Health"
        >
          IRIS
        </span>
      </div>

      {/* Assistant */}
      <button
        onClick={togglePanel}
        title="AI audit assistant"
        className="w-10 h-10 rounded-lg flex items-center justify-center transition-all"
        style={{
          backgroundColor: isOpen ? 'var(--accent-subtle)' : 'transparent',
          color: isOpen ? 'var(--accent-primary)' : 'var(--text-tertiary)',
          border: isOpen ? '1px solid var(--border-focus)' : '1px solid transparent',
        }}
      >
        <MessageSquare size={20} />
      </button>
    </aside>
  );
}
