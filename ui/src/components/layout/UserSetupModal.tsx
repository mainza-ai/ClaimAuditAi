import { useState } from 'react';
import { useUserStore } from '../../store/userStore';
import { useRoleStore, type UserRole } from '../../store/roleStore';
import { User, ShieldCheck } from 'lucide-react';

const ROLES = [
  { value: 'Auditor' as UserRole, label: 'Auditor', description: 'Can review, escalate, and recommend approval on held claims' },
  { value: 'Director' as UserRole, label: 'Director', description: 'Can approve, reject, and override escalated claims' },
  { value: 'Specialist' as UserRole, label: 'Specialist', description: 'Can review claims and provide recommendations (view-only adjudication)' },
  { value: 'Tech Owner / Admin' as UserRole, label: 'Tech Owner / Admin', description: 'Full access including data management and system configuration' },
];

const ROLE_MAP: Record<string, 'auditor' | 'director' | 'admin'> = {
  'Auditor': 'auditor',
  'Director': 'director',
  'Specialist': 'auditor',
  'Tech Owner / Admin': 'admin',
};

export function UserSetupModal() {
  const { setUser } = useUserStore();
  const { setActiveRole } = useRoleStore();
  const [name, setName] = useState('');
  const [role, setRole] = useState<UserRole>('Auditor');
  const [error, setError] = useState('');

  function handleSubmit() {
    if (!name.trim()) {
      setError('Please enter your name.');
      return;
    }
    setUser(name.trim(), ROLE_MAP[role] || 'auditor');
    setActiveRole(role);
  }

  return (
    <div
      style={{
        position: 'fixed', inset: 0, backgroundColor: 'rgba(0,0,0,0.6)',
        display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 200,
      }}
    >
      <div className="card" style={{ width: 480, maxWidth: '90vw', padding: 32, display: 'flex', flexDirection: 'column', gap: 24 }}>
        <div style={{ textAlign: 'center' }}>
          <div style={{ width: 48, height: 48, backgroundColor: 'var(--accent-primary)', borderRadius: 12, display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px' }}>
            <ShieldCheck size={24} color="white" />
          </div>
          <h2 style={{ margin: 0, fontSize: 20, fontWeight: 600, color: 'var(--text-primary)' }}>Welcome to ClaimAuditAI</h2>
          <p style={{ margin: '8px 0 0', fontSize: 13, color: 'var(--text-secondary)' }}>
            Identify yourself to begin your audit session. Your name and role will be recorded in all audit ledger entries.
          </p>
        </div>

        <div>
          <label style={{ fontSize: 13, fontWeight: 500, color: 'var(--text-secondary)', display: 'block', marginBottom: 6 }}>
            Full name <span style={{ color: 'var(--color-danger)' }}>*</span>
          </label>
          <div style={{ position: 'relative' }}>
            <User size={15} style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--text-tertiary)', pointerEvents: 'none' }} />
            <input
              type="text" value={name} onChange={(e) => { setName(e.target.value); setError(''); }}
              placeholder="e.g. Dr. Sarah Chen"
              className="input" style={{ paddingLeft: 36 }}
              onKeyDown={(e) => e.key === 'Enter' && handleSubmit()}
              autoFocus
            />
          </div>
          {error && <p style={{ margin: '4px 0 0', fontSize: 12, color: 'var(--color-danger)' }}>{error}</p>}
        </div>

        <div>
          <label style={{ fontSize: 13, fontWeight: 500, color: 'var(--text-secondary)', display: 'block', marginBottom: 8 }}>Role</label>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {ROLES.map((r) => (
              <label key={r.value} style={{ display: 'flex', alignItems: 'flex-start', gap: 12, padding: 12, border: `1px solid ${role === r.value ? 'var(--accent-primary)' : 'var(--border-default)'}`, borderRadius: 8, backgroundColor: role === r.value ? 'var(--accent-subtle)' : 'transparent', cursor: 'pointer', transition: 'all 0.15s ease' }}>
                <input type="radio" name="role" value={r.value} checked={role === r.value} onChange={() => setRole(r.value)} style={{ marginTop: 2, accentColor: 'var(--accent-primary)' }} />
                <div>
                  <p style={{ margin: 0, fontSize: 13, fontWeight: 500, color: 'var(--text-primary)' }}>{r.label}</p>
                  <p style={{ margin: '2px 0 0', fontSize: 12, color: 'var(--text-tertiary)' }}>{r.description}</p>
                </div>
              </label>
            ))}
          </div>
        </div>

        <button onClick={handleSubmit} className="btn-primary" style={{ width: '100%', justifyContent: 'center' }}>
          Begin Audit Session
        </button>
      </div>
    </div>
  );
}
