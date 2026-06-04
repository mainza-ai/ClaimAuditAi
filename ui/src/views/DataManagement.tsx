import { useState, useRef } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '../api/client';
import { useRoleStore } from '../store/roleStore';
import { PERMISSIONS } from '../utils/permissions';
import { Trash2, Database, Upload, RefreshCw, CheckCircle, AlertTriangle, FileJson, Cpu, Activity, Server, Brain, Bot, GitBranch } from 'lucide-react';

interface DataStatus {
  claimResponses: number;
  tasks: number;
  claims: number;
  patients: number;
  documentReferences: number;
  communicationRequests: number;
  projectionClaims: number;
  projectionPatients: number;
  projectionProviders: number;
  clinicalNotes: number;
  lastSeededAt: string;
}

export function DataManagement() {
  const { activeRole } = useRoleStore();
  const qc = useQueryClient();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [uploadStatus, setUploadStatus] = useState<'idle' | 'loading' | 'success' | 'error'>('idle');
  const [uploadMessage, setUploadMessage] = useState('');
  const [confirmClear, setConfirmClear] = useState(false);

  if (!PERMISSIONS.canManageData(activeRole)) {
    return (
      <div style={{ padding: 40, textAlign: 'center' }}>
        <AlertTriangle size={32} style={{ color: 'var(--color-warning)', marginBottom: 16 }} />
        <h2 style={{ color: 'var(--text-primary)', margin: 0 }}>Access Restricted</h2>
        <p style={{ color: 'var(--text-secondary)', marginTop: 8 }}>Data management requires Tech Owner / Admin role.</p>
      </div>
    );
  }

  const { data: status, refetch: refetchStatus } = useQuery<DataStatus>({
    queryKey: ['data-status'],
    queryFn: () => apiClient.get('/system/status').then(r => r.data),
  });

  const clearData = useMutation({
    mutationFn: () => apiClient.post('/system/clear'),
    onSuccess: () => {
      setConfirmClear(false);
      qc.invalidateQueries({ queryKey: ['claims'] });
      qc.invalidateQueries({ queryKey: ['stats'] });
      refetchStatus();
    },
  });

  const seedData = useMutation({
    mutationFn: () => apiClient.post('/samples/load', {}, { timeout: 300000 }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['claims'] });
      qc.invalidateQueries({ queryKey: ['stats'] });
      refetchStatus();
    },
  });

  const retrainModel = useMutation({
    mutationFn: () => apiClient.post('/system/retrain-model'),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['stats'] });
    },
  });

  const { data: health, refetch: refetchHealth } = useQuery<any>({
    queryKey: ['system-health'],
    queryFn: () => apiClient.get('/system/health').then(r => r.data),
    refetchInterval: 60000,
  });

  const statusCards = [
    { label: 'Claim Responses', value: status?.claimResponses ?? '\u2014', icon: FileJson },
    { label: 'Tasks', value: status?.tasks ?? '\u2014', icon: Database },
    { label: 'Claims', value: status?.claims ?? '\u2014', icon: Database },
    { label: 'Patients', value: status?.patients ?? '\u2014', icon: Database },
    { label: 'Document References', value: status?.documentReferences ?? '\u2014', icon: Database },
    { label: 'Comm. Requests', value: status?.communicationRequests ?? '\u2014', icon: Database },
    { label: 'Projections (Claims)', value: status?.projectionClaims ?? '\u2014', icon: Database },
    { label: 'Projections (Patients)', value: status?.projectionPatients ?? '\u2014', icon: Database },
    { label: 'Projections (Providers)', value: status?.projectionProviders ?? '\u2014', icon: Database },
    { label: 'Clinical Notes', value: status?.clinicalNotes ?? '\u2014', icon: Database },
  ];

  return (
    <div style={{ maxWidth: 720, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <div>
        <h1 style={{ margin: 0, fontSize: 20, fontWeight: 600, color: 'var(--text-primary)' }}>Data Management</h1>
        <p style={{ margin: '6px 0 0', fontSize: 13, color: 'var(--text-secondary)' }}>
          Manage FHIR sample data for testing and demonstration. Actions here directly affect the IRIS FHIR repository.
        </p>
      </div>

      <div className="card" style={{ padding: 20 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
          <h2 style={{ margin: 0, fontSize: 14, fontWeight: 600, color: 'var(--text-primary)' }}>Current FHIR Repository</h2>
          <button onClick={() => refetchStatus()} className="btn-ghost" style={{ fontSize: 12, display: 'flex', alignItems: 'center', gap: 6 }}>
            <RefreshCw size={13} /> Refresh
          </button>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 12 }}>
          {statusCards.map(({ label, value, icon: Icon }) => (
            <div key={label} style={{ padding: 16, backgroundColor: 'var(--bg-page)', borderRadius: 8, border: '1px solid var(--border-default)', textAlign: 'center' }}>
              <Icon size={20} style={{ color: 'var(--accent-primary)', marginBottom: 8 }} />
              <p style={{ margin: 0, fontSize: 24, fontWeight: 700, color: 'var(--text-primary)', fontFamily: 'var(--font-mono)' }}>{value}</p>
              <p style={{ margin: '4px 0 0', fontSize: 12, color: 'var(--text-tertiary)' }}>{label}</p>
            </div>
          ))}
        </div>
        {status?.lastSeededAt && (
          <p style={{ margin: '12px 0 0', fontSize: 12, color: 'var(--text-secondary)', fontFamily: 'var(--font-mono)' }}>
            Last seeded: {new Date(status.lastSeededAt).toLocaleString()}
          </p>
        )}
      </div>

      <div className="card" style={{ padding: 20 }}>
        <h2 style={{ margin: '0 0 8px', fontSize: 14, fontWeight: 600, color: 'var(--text-primary)' }}>Seed Sample Data</h2>
        <p style={{ margin: '0 0 16px', fontSize: 13, color: 'var(--text-secondary)' }}>
          Loads FHIR sample bundles into the repository. Uses the existing /samples/load endpoint.
        </p>
        <button
          onClick={() => seedData.mutate()}
          disabled={seedData.isPending}
          className="btn-primary"
          style={{ display: 'flex', alignItems: 'center', gap: 8 }}
        >
          <Database size={15} />
          {seedData.isPending ? 'Seeding...' : 'Seed Sample Data'}
        </button>
        {seedData.isSuccess && (
          <p style={{ margin: '10px 0 0', fontSize: 13, color: 'var(--color-success)', display: 'flex', alignItems: 'center', gap: 6 }}>
            <CheckCircle size={14} /> Sample data seeded successfully.
          </p>
        )}
        {seedData.isError && (
          <p style={{ margin: '10px 0 0', fontSize: 13, color: 'var(--color-danger)' }}>
            Error seeding data: {(seedData.error as Error)?.message || 'Unknown error'}
          </p>
        )}
      </div>

      <div className="card" style={{ padding: 20 }}>
        <h2 style={{ margin: '0 0 8px', fontSize: 14, fontWeight: 600, color: 'var(--text-primary)' }}>Retrain Autoencoder Model</h2>
        <p style={{ margin: '0 0 16px', fontSize: 13, color: 'var(--text-secondary)' }}>
          Manually retrain the autoencoder on current ClaimProjections data. Requires at least 5 claim projections to produce a meaningful model.
        </p>
        <button
          onClick={() => retrainModel.mutate()}
          disabled={retrainModel.isPending}
          className="btn-primary"
          style={{ display: 'flex', alignItems: 'center', gap: 8 }}
        >
          <Cpu size={15} />
          {retrainModel.isPending ? 'Training...' : 'Retrain Model'}
        </button>
        {retrainModel.isSuccess && (
          <p style={{ margin: '10px 0 0', fontSize: 13, color: 'var(--color-success)', display: 'flex', alignItems: 'center', gap: 6 }}>
            <CheckCircle size={14} /> {(retrainModel.data as any)?.data?.message || 'Model retrained successfully.'}
          </p>
        )}
        {retrainModel.isError && (
          <p style={{ margin: '10px 0 0', fontSize: 13, color: 'var(--color-danger)' }}>
            Error: {(retrainModel.error as Error)?.message || 'Retraining failed'}
          </p>
        )}
      </div>

      <div className="card" style={{ padding: 20 }}>
        <h2 style={{ margin: '0 0 8px', fontSize: 14, fontWeight: 600, color: 'var(--text-primary)' }}>Upload External Claim Data</h2>
        <p style={{ margin: '0 0 16px', fontSize: 13, color: 'var(--text-secondary)' }}>
          Upload a FHIR JSON file from your host system. Must be a valid FHIR R4 <strong>Claim</strong> resource or a <strong>Bundle</strong>.
        </p>
        <div
          onClick={() => fileInputRef.current?.click()}
          style={{ border: `2px dashed ${uploadStatus === 'error' ? 'var(--color-danger-border)' : 'var(--border-strong)'}`, borderRadius: 8, padding: 32, textAlign: 'center', cursor: 'pointer', backgroundColor: 'var(--bg-page)' }}
        >
          <Upload size={24} style={{ color: 'var(--text-tertiary)', marginBottom: 12 }} />
          <p style={{ margin: 0, fontSize: 14, color: 'var(--text-primary)', fontWeight: 500 }}>Click to upload a FHIR JSON file</p>
          <p style={{ margin: '4px 0 0', fontSize: 12, color: 'var(--text-tertiary)' }}>FHIR R4 JSON \u2014 Claim or Bundle resource (max 10 MB)</p>
          <input ref={fileInputRef} type="file" accept=".json,application/json" style={{ display: 'none' }}
            onChange={async (e) => {
              const file = e.target.files?.[0];
              if (!file) return;
              if (!file.name.endsWith('.json')) { setUploadStatus('error'); setUploadMessage('Only JSON files are supported.'); return; }
              if (file.size > 10 * 1024 * 1024) { setUploadStatus('error'); setUploadMessage('File size exceeds the 10 MB limit.'); return; }
              setUploadStatus('loading');
              try {
                const text = await file.text();
                const jsonData = JSON.parse(text);
                const res = await apiClient.post('/system/upload', jsonData);
                setUploadStatus('success');
                setUploadMessage(`Successfully submitted${res.data?.projectionsCreated ? ` with ${res.data.projectionsCreated} projections` : ''}. FHIR status: ${res.data?.fhirStatus || 'OK'}`);
                qc.invalidateQueries({ queryKey: ['claims'] });
                refetchStatus();
                if (fileInputRef.current) fileInputRef.current.value = '';
              } catch (err: any) {
                setUploadStatus('error');
                setUploadMessage(err?.response?.data?.error || err?.message || 'Upload failed');
              }
            }}
          />
        </div>
        {uploadStatus === 'loading' && <p style={{ margin: '12px 0 0', fontSize: 13, color: 'var(--text-secondary)', display: 'flex', alignItems: 'center', gap: 6 }}><RefreshCw size={13} className="animate-spin" /> Submitting...</p>}
        {uploadStatus === 'success' && <p style={{ margin: '12px 0 0', fontSize: 13, color: 'var(--color-success)', display: 'flex', alignItems: 'center', gap: 6 }}><CheckCircle size={14} /> {uploadMessage}</p>}
        {uploadStatus === 'error' && <p style={{ margin: '12px 0 0', fontSize: 13, color: 'var(--color-danger)', display: 'flex', alignItems: 'center', gap: 6 }}><AlertTriangle size={14} /> {uploadMessage}</p>}
      </div>

      <div className="card" style={{ padding: 20, border: '1px solid var(--color-danger-border)', backgroundColor: 'var(--color-danger-bg)' }}>
        <h2 style={{ margin: '0 0 8px', fontSize: 14, fontWeight: 600, color: 'var(--color-danger)' }}>Danger Zone \u2014 Clear All Data</h2>
        <p style={{ margin: '0 0 16px', fontSize: 13, color: 'var(--text-secondary)' }}>
          This cannot be undone. All FHIR resources (Claims, ClaimResponses, Tasks, CommunicationRequests, Patients, DocumentReferences) and all projection tables (ClaimProjections, PatientProjections, ProviderProjections, ClinicalNotes) will be permanently deleted.
        </p>
        {!confirmClear ? (
          <button onClick={() => setConfirmClear(true)} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 16px', borderRadius: 6, border: '1px solid var(--color-danger-border)', backgroundColor: 'transparent', color: 'var(--color-danger)', fontSize: 14, fontWeight: 500, cursor: 'pointer' }}>
            <Trash2 size={15} /> Clear All Sample Data
          </button>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <p style={{ margin: 0, fontSize: 13, fontWeight: 600, color: 'var(--color-danger)' }}>Are you sure? This will delete all FHIR resources.</p>
            <div style={{ display: 'flex', gap: 8 }}>
              <button
                onClick={() => clearData.mutate()}
                disabled={clearData.isPending}
                style={{ padding: '8px 16px', borderRadius: 6, border: 'none', backgroundColor: 'var(--color-danger)', color: 'white', fontSize: 14, fontWeight: 500, cursor: 'pointer', opacity: clearData.isPending ? 0.5 : 1 }}
              >
                {clearData.isPending ? 'Clearing...' : 'Yes, delete everything'}
              </button>
              <button onClick={() => setConfirmClear(false)} className="btn-ghost">Cancel</button>
            </div>
          </div>
        )}
        {clearData.isSuccess && (
          <p style={{ margin: '10px 0 0', fontSize: 13, color: 'var(--color-success)', display: 'flex', alignItems: 'center', gap: 6 }}>
            <CheckCircle size={14} /> All data cleared successfully.
          </p>
        )}
      </div>

      <div className="card" style={{ padding: 20 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
          <h2 style={{ margin: 0, fontSize: 14, fontWeight: 600, color: 'var(--text-primary)' }}>System Health</h2>
          <button onClick={() => refetchHealth()} className="btn-ghost" style={{ fontSize: 12, display: 'flex', alignItems: 'center', gap: 6 }}>
            <RefreshCw size={13} /> Refresh
          </button>
        </div>
        {health && (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
            {[
              { key: 'fhirEndpoint', label: 'FHIR Endpoint', icon: Server },
              { key: 'pythonBridge', label: 'Python Bridge', icon: Activity },
              { key: 'autoencoder', label: 'Autoencoder', icon: Brain },
              { key: 'graphEngine', label: 'Graph Engine', icon: GitBranch },
              { key: 'llm', label: 'LLM Provider', icon: Bot },
            ].map(({ key, label, icon: Icon }) => {
              const c = health.components?.[key];
              const status = c?.status || 'unknown';
              const color = status === 'healthy' ? 'var(--color-success)' : status === 'untrained' || status === 'unknown' ? 'var(--color-warning)' : 'var(--color-danger)';
              const extra = key === 'autoencoder' && c?.threshold ? ` (threshold: ${c.threshold.toFixed(4)})` : key === 'llm' && c?.provider ? ` (${c.provider})` : '';
              return (
                <div key={key} style={{ padding: 10, borderRadius: 6, backgroundColor: 'var(--bg-page)', border: `1px solid ${color}`, display: 'flex', alignItems: 'center', gap: 8 }}>
                  <Icon size={14} style={{ color, flexShrink: 0 }} />
                  <div style={{ minWidth: 0 }}>
                    <p style={{ margin: 0, fontSize: 11, fontWeight: 600, color: 'var(--text-primary)' }}>{label}<span style={{ fontSize: 10, marginLeft: 4, color, fontWeight: 400 }}>{extra}</span></p>
                    <p style={{ margin: 0, fontSize: 11, color, fontFamily: 'var(--font-mono)' }}>{status}</p>
                  </div>
                </div>
              );
            })}
          </div>
        )}
        {!health && (
          <p style={{ margin: 0, fontSize: 13, color: 'var(--text-tertiary)' }}>Loading system health...</p>
        )}
      </div>
    </div>
  );
}
