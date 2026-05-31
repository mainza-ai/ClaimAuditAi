import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { login } from '../api/auth';
import { useRoleStore } from '../store/roleStore';

export function LoginPage() {
  const navigate = useNavigate();
  const { setAuthContext } = useRoleStore();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleLogin = async (e: FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const { claims } = await login(username, password);
      setAuthContext(claims.name || claims.sub, claims.fhirUser, claims.roles || []);
      navigate('/dashboard', { replace: true });
    } catch (err: any) {
      setError(err.message || 'Login failed. Please check your credentials.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        minHeight: '100vh',
        backgroundColor: 'var(--bg-page)',
        color: 'var(--text-primary)',
      }}
    >
      <div
        style={{
          width: '100%',
          maxWidth: 400,
          padding: 40,
          backgroundColor: 'var(--bg-card)',
          borderRadius: 12,
          border: '1px solid var(--border-default)',
          boxShadow: 'var(--shadow-modal)',
        }}
      >
        <div style={{ textAlign: 'center', marginBottom: 32 }}>
          <img src="/logo.png" alt="ClaimAuditAI" style={{ width: 48, height: 48, marginBottom: 16 }} />
          <h1 style={{ fontSize: 20, fontWeight: 700, margin: '0 0 4px' }}>
            ClaimAuditAI
          </h1>
          <p style={{ fontSize: 13, color: 'var(--text-secondary)', margin: 0 }}>
            SMART on FHIR Authentication
          </p>
        </div>

        <form onSubmit={handleLogin}>
          {error && (
            <div
              style={{
                backgroundColor: 'var(--color-danger-bg)',
                color: 'var(--color-danger)',
                border: '1px solid var(--color-danger-border)',
                borderRadius: 6,
                padding: '10px 14px',
                fontSize: 13,
                marginBottom: 20,
              }}
              role="alert"
            >
              {error}
            </div>
          )}

          <div style={{ marginBottom: 16 }}>
            <label
              htmlFor="username"
              style={{
                display: 'block',
                fontSize: 12,
                fontWeight: 600,
                color: 'var(--text-secondary)',
                marginBottom: 6,
              }}
            >
              Username
            </label>
            <input
              id="username"
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              autoComplete="username"
              required
              autoFocus
              style={{
                width: '100%',
                padding: '10px 12px',
                borderRadius: 6,
                border: '1px solid var(--border-default)',
                backgroundColor: 'var(--bg-input)',
                color: 'var(--text-primary)',
                fontSize: 14,
                fontFamily: 'var(--font-sans)',
                outline: 'none',
                boxSizing: 'border-box',
              }}
              onFocus={(e) => {
                e.target.style.borderColor = 'var(--accent-primary)';
                e.target.style.boxShadow = '0 0 0 3px var(--accent-subtle)';
              }}
              onBlur={(e) => {
                e.target.style.borderColor = 'var(--border-default)';
                e.target.style.boxShadow = 'none';
              }}
            />
          </div>

          <div style={{ marginBottom: 24 }}>
            <label
              htmlFor="password"
              style={{
                display: 'block',
                fontSize: 12,
                fontWeight: 600,
                color: 'var(--text-secondary)',
                marginBottom: 6,
              }}
            >
              Password
            </label>
            <input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
              required
              style={{
                width: '100%',
                padding: '10px 12px',
                borderRadius: 6,
                border: '1px solid var(--border-default)',
                backgroundColor: 'var(--bg-input)',
                color: 'var(--text-primary)',
                fontSize: 14,
                fontFamily: 'var(--font-sans)',
                outline: 'none',
                boxSizing: 'border-box',
              }}
              onFocus={(e) => {
                e.target.style.borderColor = 'var(--accent-primary)';
                e.target.style.boxShadow = '0 0 0 3px var(--accent-subtle)';
              }}
              onBlur={(e) => {
                e.target.style.borderColor = 'var(--border-default)';
                e.target.style.boxShadow = 'none';
              }}
            />
          </div>

          <button
            type="submit"
            disabled={loading || !username || !password}
            style={{
              width: '100%',
              padding: '12px 16px',
              borderRadius: 6,
              border: 'none',
              backgroundColor: 'var(--accent-primary)',
              color: '#FFFFFF',
              fontSize: 14,
              fontWeight: 600,
              cursor: loading || !username || !password ? 'not-allowed' : 'pointer',
              opacity: loading || !username || !password ? 0.6 : 1,
              fontFamily: 'var(--font-sans)',
            }}
          >
            {loading ? 'Authenticating...' : 'Sign In with SMART on FHIR'}
          </button>
        </form>

        <p style={{ textAlign: 'center', fontSize: 11, color: 'var(--text-tertiary)', marginTop: 24 }}>
          OAuth2 Resource Owner Password Grant
        </p>
      </div>
    </div>
  );
}
