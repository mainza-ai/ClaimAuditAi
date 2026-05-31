import { useState, useRef } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '../api/client';
import { useUserStore } from '../store/userStore';
import { PERMISSIONS } from '../utils/permissions';
import { Trash2, Database, Upload, RefreshCw, CheckCircle, AlertTriangle, FileJson } from 'lucide-react';

interface DataStatus {
  claims: number;
  claimResponses: number;
  patients: number;
}

export function DataManagement() {
  const { role } = useUserStore();
  const qc = useQueryClient();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [uploadStatus, setUploadStatus] = useState<'idle' | 'loading' | 'success' | 'error'>('idle');
  const [uploadMessage, setUploadMessage] = useState('');
  const [confirmClear, setConfirmClear] = useState(false);

  if (!PERMISSIONS.canManageData(role)) {
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
    queryFn: () => apiClient.get('/stats').then(r => ({
      claims: 0, claimResponses: r.data.interceptedTotal ?? 0, patients: 0,
    })),
  });

  const statusCards = [
    { label: 'Claims', value: status?.claimResponses ?? '\u2014', icon: FileJson },
    { label: 'Claim Responses', value: status?.claimResponses ?? '\u2014', icon: Database },
    { label: 'Patients', value: status?.patients ?? '\u2014', icon: Database },
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
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12 }}>
          {statusCards.map(({ label, value, icon: Icon }) => (
            <div key={label} style={{ padding: 16, backgroundColor: 'var(--bg-page)', borderRadius: 8, border: '1px solid var(--border-default)', textAlign: 'center' }}>
              <Icon size={20} style={{ color: 'var(--accent-primary)', marginBottom: 8 }} />
              <p style={{ margin: 0, fontSize: 24, fontWeight: 700, color: 'var(--text-primary)', fontFamily: 'var(--font-mono)' }}>{value}</p>
              <p style={{ margin: '4px 0 0', fontSize: 12, color: 'var(--text-tertiary)' }}>{label}</p>
            </div>
          ))}
        </div>
      </div>

      <div className="card" style={{ padding: 20 }}>
        <h2 style={{ margin: '0 0 8px', fontSize: 14, fontWeight: 600, color: 'var(--text-primary)' }}>Seed Sample Data</h2>
        <p style={{ margin: '0 0 16px', fontSize: 13, color: 'var(--text-secondary)' }}>
          Uses the existing Seed Sample Data endpoint to load FHIR sample bundles into the repository.
        </p>
        <button
          onClick={() => apiClient.post('/samples/load', {}, { timeout: 120000 }).then(() => {
            qc.invalidateQueries({ queryKey: ['claims'] });
            qc.invalidateQueries({ queryKey: ['stats'] });
            refetchStatus();
          })}
          className="btn-primary"
          style={{ display: 'flex', alignItems: 'center', gap: 8 }}
        >
          <Database size={15} /> Seed Sample Data
        </button>
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
          <p style={{ margin: 0, fontSize: 14, color: 'var(--text-primary)', fontWeight: 500 }}>Click to upload or drag and drop</p>
          <p style={{ margin: '4px 0 0', fontSize: 12, color: 'var(--text-tertiary)' }}>FHIR R4 JSON \u2014 Claim or Bundle resource</p>
          <input ref={fileInputRef} type="file" accept=".json,application/json" style={{ display: 'none' }}
            onChange={async (e) => {
              const file = e.target.files?.[0];
              if (!file) return;
              if (!file.name.endsWith('.json')) { setUploadStatus('error'); setUploadMessage('Only JSON files are supported.'); return; }
              setUploadStatus('loading');
              try {
                const text = await file.text();
                JSON.parse(text);
                const res = await apiClient.post('/admin/data/upload', JSON.parse(text));
                setUploadStatus('success');
                setUploadMessage(`Successfully submitted. FHIR response: ${res.data?.fhirResponse?.resourceType || 'OK'}`);
                qc.invalidateQueries({ queryKey: ['claims'] });
                refetchStatus();
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
          This cannot be undone. All Claim, ClaimResponse, Patient, Task, and CommunicationRequest resources will be permanently deleted.
        </p>
        {!confirmClear ? (
          <button onClick={() => setConfirmClear(true)} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 16px', borderRadius: 6, border: '1px solid var(--color-danger-border)', backgroundColor: 'transparent', color: 'var(--color-danger)', fontSize: 14, fontWeight: 500, cursor: 'pointer' }}>
            <Trash2 size={15} /> Clear All Sample Data
          </button>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <p style={{ margin: 0, fontSize: 13, fontWeight: 600, color: 'var(--color-danger)' }}>Are you sure? This will delete all FHIR resources.</p>
            <div style={{ display: 'flex', gap: 8 }}>
              <button onClick={() => { setConfirmClear(false); }} style={{ padding: '8px 16px', borderRadius: 6, border: 'none', backgroundColor: 'var(--color-danger)', color: 'white', fontSize: 14, fontWeight: 500, cursor: 'pointer' }}>Yes, delete everything</button>
              <button onClick={() => setConfirmClear(false)} className="btn-ghost">Cancel</button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
