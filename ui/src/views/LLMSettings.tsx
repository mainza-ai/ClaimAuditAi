import { useState, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '../api/client';
import { Save, RefreshCw, CheckCircle, AlertTriangle } from 'lucide-react';

type Provider = 'nvidia' | 'ollama' | 'openai';

interface LLMSettingsData {
  provider: Provider;
  nvidiaModel: string;
  nvidiaBaseUrl: string;
  ollamaBaseUrl: string;
  ollamaModel: string;
  openaiModel: string;
  rateLimitPerMin?: number;
  cacheTTL?: number;
}

export function LLMSettings() {
  const qc = useQueryClient();

  const { data: settings, isLoading, isError } = useQuery<LLMSettingsData>({
    queryKey: ['llm-settings'],
    queryFn: () => apiClient.get('/settings/llm').then(r => r.data),
  });

  const [provider, setProvider] = useState<Provider>('nvidia');
  const [nvidiaModel, setNvidiaModel] = useState('nvidia/nemotron-3-super-120b-a12b');
  const [nvidiaKey, setNvidiaKey] = useState('');
  const [nvidiaBaseUrl, setNvidiaBaseUrl] = useState('https://integrate.api.nvidia.com/v1');
  const [ollamaBaseUrl, setOllamaBaseUrl] = useState('http://localhost:11434');
  const [ollamaModel, setOllamaModel] = useState('');
  const [openaiModel, setOpenaiModel] = useState('gpt-4');
  const [openaiKey, setOpenaiKey] = useState('');
  const [rateLimitPerMin, setRateLimitPerMin] = useState(120);
  const [cacheTTL, setCacheTTL] = useState(86400);
  const [ollamaModels, setOllamaModels] = useState<string[]>([]);
  const [ollamaStatus, setOllamaStatus] = useState<'idle' | 'loading' | 'ok' | 'error'>('idle');
  const [dirty, setDirty] = useState(false);

  useEffect(() => {
    if (settings) {
      setProvider(settings.provider || 'nvidia');
      setNvidiaModel(settings.nvidiaModel || 'nvidia/nemotron-3-super-120b-a12b');
      setNvidiaBaseUrl(settings.nvidiaBaseUrl || 'https://integrate.api.nvidia.com/v1');
      setOllamaBaseUrl(settings.ollamaBaseUrl || 'http://localhost:11434');
      setOllamaModel(settings.ollamaModel || '');
      setOpenaiModel(settings.openaiModel || 'gpt-4');
      setRateLimitPerMin(settings.rateLimitPerMin !== undefined ? settings.rateLimitPerMin : 120);
      setCacheTTL(settings.cacheTTL !== undefined ? settings.cacheTTL : 86400);
    }
  }, [settings]);

  const save = useMutation({
    mutationFn: (payload: Record<string, unknown>) =>
      apiClient.post('/settings/llm', payload).then(r => r.data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['llm-settings'] });
      setDirty(false);
    },
    onError: () => {
      // error state handled by isError in JSX
    },
  });

  async function fetchOllamaModels() {
    setOllamaStatus('loading');
    try {
      const res = await apiClient.get('/settings/llm/ollama/models', {
        params: { baseUrl: ollamaBaseUrl },
      });
      const models: string[] = Array.isArray(res.data) ? res.data : [];
      setOllamaModels(models);
      setOllamaStatus(models.length > 0 ? 'ok' : 'error');
      if (models.length > 0 && !ollamaModel) setOllamaModel(models[0]);
    } catch {
      setOllamaModels([]);
      setOllamaStatus('error');
    }
  }

  function handleSave() {
    setDirty(false);
    const payload: Record<string, unknown> = {
      provider,
      rateLimitPerMin: Number(rateLimitPerMin),
      cacheTTL: Number(cacheTTL),
    };
    if (provider === 'nvidia') {
      payload.nvidiaModel = nvidiaModel;
      payload.nvidiaBaseUrl = nvidiaBaseUrl;
      if (nvidiaKey) payload.nvidiaApiKey = nvidiaKey;
    } else if (provider === 'ollama') {
      payload.ollamaBaseUrl = ollamaBaseUrl;
      payload.ollamaModel = ollamaModel;
    } else if (provider === 'openai') {
      payload.openaiModel = openaiModel;
      if (openaiKey) payload.openaiApiKey = openaiKey;
    }
    save.mutate(payload);
  }

  if (isLoading) return <div style={{ color: 'var(--text-secondary)', padding: 24 }}>Loading settings...</div>;
  if (isError) return (
    <div style={{ color: 'var(--color-danger)', padding: 24, textAlign: 'center' }}>
      <AlertTriangle size={24} style={{ marginBottom: 12 }} />
      <p>Failed to load LLM settings. Server may be unavailable.</p>
    </div>
  );

  const PROVIDERS: { value: Provider; label: string; description: string }[] = [
    {
      value: 'nvidia',
      label: 'NVIDIA NIM',
      description: 'Cloud-based. Requires NVIDIA API key. Default model: nvidia/nemotron-3-super-120b-a12b',
    },
    {
      value: 'ollama',
      label: 'Ollama (Local)',
      description: 'Runs locally on your machine. No API key required. Models pulled via `ollama pull <model>`.',
    },
    {
      value: 'openai',
      label: 'OpenAI',
      description: 'Cloud-based. Requires OpenAI API key.',
    },
  ];

  return (
    <div style={{ maxWidth: 640, padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <div>
        <h1 style={{ margin: 0, fontSize: 20, fontWeight: 600, color: 'var(--text-primary)' }}>
          LLM Provider Settings
        </h1>
        <p style={{ margin: '6px 0 0', fontSize: 13, color: 'var(--text-secondary)' }}>
          Configure which AI provider powers adjudication, audit reports, and the AI chat assistant.
          Changes take effect immediately \u2014 no restart required.
        </p>
      </div>

      <div className="card" style={{ padding: 20, display: 'flex', flexDirection: 'column', gap: 12 }}>
        <p style={{ margin: 0, fontSize: 12, fontWeight: 600, color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.06em' }}>
          Select Provider
        </p>
        {PROVIDERS.map(p => (
          <label
            key={p.value}
            style={{
              display: 'flex', alignItems: 'flex-start', gap: 12, padding: 14,
              border: `1px solid ${provider === p.value ? 'var(--accent-primary)' : 'var(--border-default)'}`,
              borderRadius: 8, backgroundColor: provider === p.value ? 'var(--accent-subtle)' : 'var(--bg-page)',
              cursor: 'pointer', transition: 'all 0.15s ease',
            }}
          >
            <input
              type="radio"
              name="provider"
              value={p.value}
              checked={provider === p.value}
              onChange={() => { setProvider(p.value); setDirty(true); }}
              style={{ marginTop: 2, accentColor: 'var(--accent-primary)' }}
            />
            <div>
              <p style={{ margin: 0, fontSize: 14, fontWeight: 500, color: 'var(--text-primary)' }}>
                {p.label}
                {p.value === 'nvidia' && (
                  <span style={{ marginLeft: 8, fontSize: 10, padding: '2px 6px', borderRadius: 4, backgroundColor: 'var(--accent-subtle)', color: 'var(--accent-text)', fontWeight: 600 }}>
                    DEFAULT
                  </span>
                )}
              </p>
              <p style={{ margin: '3px 0 0', fontSize: 12, color: 'var(--text-tertiary)' }}>
                {p.description}
              </p>
            </div>
          </label>
        ))}
      </div>

      {provider === 'nvidia' && (
        <div className="card" style={{ padding: 20, display: 'flex', flexDirection: 'column', gap: 14 }}>
          <p style={{ margin: 0, fontSize: 12, fontWeight: 600, color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.06em' }}>
            NVIDIA NIM Configuration
          </p>
          <div>
            <label style={{ fontSize: 13, fontWeight: 500, color: 'var(--text-secondary)', display: 'block', marginBottom: 6 }}>
              API Key
            </label>
            <input
              type="password"
              placeholder="Leave blank to keep existing key"
              value={nvidiaKey}
              onChange={e => setNvidiaKey(e.target.value)}
              className="input"
            />
          </div>
          <div>
            <label style={{ fontSize: 13, fontWeight: 500, color: 'var(--text-secondary)', display: 'block', marginBottom: 6 }}>Base URL</label>
            <input type="text" value={nvidiaBaseUrl} onChange={e => setNvidiaBaseUrl(e.target.value)} className="input" />
          </div>
          <div>
            <label style={{ fontSize: 13, fontWeight: 500, color: 'var(--text-secondary)', display: 'block', marginBottom: 6 }}>Model</label>
            <input type="text" value={nvidiaModel} onChange={e => setNvidiaModel(e.target.value)} className="input" placeholder="nvidia/nemotron-3-super-120b-a12b" />
          </div>
        </div>
      )}

      {provider === 'ollama' && (
        <div className="card" style={{ padding: 20, display: 'flex', flexDirection: 'column', gap: 14 }}>
          <p style={{ margin: 0, fontSize: 12, fontWeight: 600, color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.06em' }}>
            Ollama Configuration
          </p>
          <div>
            <label style={{ fontSize: 13, fontWeight: 500, color: 'var(--text-secondary)', display: 'block', marginBottom: 6 }}>Ollama Base URL</label>
            <div style={{ display: 'flex', gap: 8 }}>
              <input type="text" value={ollamaBaseUrl} onChange={e => setOllamaBaseUrl(e.target.value)} className="input" placeholder="http://localhost:11434" />
              <button
                onClick={fetchOllamaModels}
                className="btn-ghost"
                style={{ flexShrink: 0, display: 'flex', alignItems: 'center', gap: 6, whiteSpace: 'nowrap' }}
              >
                <RefreshCw size={14} className={ollamaStatus === 'loading' ? 'animate-spin' : ''} />
                Detect models
              </button>
            </div>
            {ollamaStatus === 'error' && <p style={{ fontSize: 12, color: 'var(--color-danger)', marginTop: 6 }}>Could not reach Ollama at that URL.</p>}
            {ollamaStatus === 'ok' && (
              <p style={{ fontSize: 12, color: 'var(--color-success)', marginTop: 6, display: 'flex', alignItems: 'center', gap: 4 }}>
                <CheckCircle size={12} /> {ollamaModels.length} model{ollamaModels.length !== 1 ? 's' : ''} found
              </p>
            )}
          </div>
          <div>
            <label style={{ fontSize: 13, fontWeight: 500, color: 'var(--text-secondary)', display: 'block', marginBottom: 6 }}>Model</label>
            {ollamaModels.length > 0 ? (
              <select
                value={ollamaModel}
                onChange={e => setOllamaModel(e.target.value)}
                style={{ width: '100%', backgroundColor: 'var(--bg-input)', border: '1px solid var(--border-default)', color: 'var(--text-primary)', borderRadius: 6, padding: '8px 12px', fontSize: 14, outline: 'none' }}
              >
                {ollamaModels.map(m => <option key={m} value={m}>{m}</option>)}
              </select>
            ) : (
              <input type="text" value={ollamaModel} onChange={e => setOllamaModel(e.target.value)} className="input" placeholder="e.g. llama3, mistral, phi3" />
            )}
          </div>
          <div style={{ padding: 12, backgroundColor: 'var(--color-warning-bg)', border: '1px solid var(--color-warning-border)', borderRadius: 6, fontSize: 12, color: 'var(--color-warning)' }}>
            <AlertTriangle size={12} style={{ display: 'inline', marginRight: 6 }} />
            When running inside Docker, Ollama on your host machine is reachable at{' '}
            <code style={{ fontFamily: 'var(--font-mono)' }}>http://host.docker.internal:11434</code>.
          </div>
        </div>
      )}

      {provider === 'openai' && (
        <div className="card" style={{ padding: 20, display: 'flex', flexDirection: 'column', gap: 14 }}>
          <p style={{ margin: 0, fontSize: 12, fontWeight: 600, color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.06em' }}>
            OpenAI Configuration
          </p>
          <div>
            <label style={{ fontSize: 13, fontWeight: 500, color: 'var(--text-secondary)', display: 'block', marginBottom: 6 }}>
              API Key
            </label>
            <input type="password" placeholder="Leave blank to keep existing key" value={openaiKey} onChange={e => setOpenaiKey(e.target.value)} className="input" />
          </div>
          <div>
            <label style={{ fontSize: 13, fontWeight: 500, color: 'var(--text-secondary)', display: 'block', marginBottom: 6 }}>Model</label>
            <select
              value={openaiModel}
              onChange={e => setOpenaiModel(e.target.value)}
              style={{ width: '100%', backgroundColor: 'var(--bg-input)', border: '1px solid var(--border-default)', color: 'var(--text-primary)', borderRadius: 6, padding: '8px 12px', fontSize: 14, outline: 'none' }}
            >
              {['gpt-4o', 'gpt-4', 'gpt-4-turbo', 'gpt-3.5-turbo'].map(m => <option key={m} value={m}>{m}</option>)}
            </select>
          </div>
        </div>
      )}

      <div className="card" style={{ padding: 20, display: 'flex', flexDirection: 'column', gap: 14 }}>
        <p style={{ margin: 0, fontSize: 12, fontWeight: 600, color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.06em' }}>
          Performance & Caching
        </p>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
          <div>
            <label style={{ fontSize: 13, fontWeight: 500, color: 'var(--text-secondary)', display: 'block', marginBottom: 6 }}>
              Rate Limit (Req/Min)
            </label>
            <input
              type="number"
              value={rateLimitPerMin}
              onChange={e => { setRateLimitPerMin(Number(e.target.value)); setDirty(true); }}
              className="input"
              min={1}
            />
          </div>
          <div>
            <label style={{ fontSize: 13, fontWeight: 500, color: 'var(--text-secondary)', display: 'block', marginBottom: 6 }}>
              Cache TTL (Seconds)
            </label>
            <input
              type="number"
              value={cacheTTL}
              onChange={e => { setCacheTTL(Number(e.target.value)); setDirty(true); }}
              className="input"
              min={0}
            />
          </div>
        </div>
        <p style={{ margin: 0, fontSize: 11, color: 'var(--text-tertiary)' }}>
          Rate limit enforces local request throttling to avoid external API limits. Caching avoids duplicate queries and reduces costs. Set Cache TTL to 0 to disable caching.
        </p>
      </div>

      <button
        onClick={handleSave}
        disabled={save.isPending}
        className="btn-primary"
        style={{ display: 'flex', alignItems: 'center', gap: 8, width: 'fit-content' }}
      >
        <Save size={15} />
        {save.isPending ? 'Saving...' : 'Save settings'}
      </button>

      {save.isSuccess && !dirty && (
        <p style={{ fontSize: 13, color: 'var(--color-success)', display: 'flex', alignItems: 'center', gap: 6 }}>
          <CheckCircle size={14} />
          Settings saved. New provider is active immediately.
        </p>
      )}
      {save.isError && (
        <p style={{ fontSize: 13, color: 'var(--color-danger)', display: 'flex', alignItems: 'center', gap: 6 }}>
          <AlertTriangle size={14} />
          Failed to save settings. Check server connection.
        </p>
      )}
    </div>
  );
}
