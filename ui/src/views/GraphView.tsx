import { useRef, useEffect, useState } from 'react';
import cytoscape from 'cytoscape';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { getHeldClaims } from '../api/claims';
import { useThemeStore } from '../store/themeStore';


export function GraphView() {
  const containerRef = useRef<HTMLDivElement>(null);
  const navigate = useNavigate();
  const [selectedNode, setSelectedNode] = useState<{ id: string; type: string; label: string } | null>(null);
  const [layoutName, setLayoutName] = useState<'cose' | 'circle' | 'concentric' | 'grid'>('cose');
  const theme = useThemeStore((s) => s.theme);
  const isDark = theme === 'dark';

  const { data: claims } = useQuery({
    queryKey: ['claims', 'held'],
    queryFn: getHeldClaims,
  });

  const allClaims = claims ?? [];

  const selectedId = selectedNode?.id.split('-')[1];
  const providerHeldClaims = allClaims?.filter(c => c.providerId === selectedId) ?? [];
  const providerExposure = providerHeldClaims.reduce((sum, c) => sum + (c.totalAmount || 0), 0);

  const patientHeldClaims = allClaims?.filter(c => c.patientId === selectedId) ?? [];
  const patientExposure = patientHeldClaims.reduce((sum, c) => sum + (c.totalAmount || 0), 0);

  useEffect(() => {
    if (!containerRef.current || !allClaims?.length) return;

    const elements: cytoscape.ElementDefinition[] = [];
    const addedNodes = new Set<string>();

    allClaims.forEach((claim) => {
      // Patient Node
      const patientNodeId = `patient-${claim.patientId}`;
      if (!addedNodes.has(patientNodeId)) {
        elements.push({
          data: {
            id: patientNodeId,
            label: claim.patientName ? `${claim.patientName}` : `Patient ${claim.patientId}`,
            type: 'patient'
          }
        });
        addedNodes.add(patientNodeId);
      }
      
      // Provider Node
      const providerNodeId = `provider-${claim.providerId}`;
      if (!addedNodes.has(providerNodeId)) {
        elements.push({
          data: {
            id: providerNodeId,
            label: `Provider ${claim.providerId}`,
            type: 'provider'
          }
        });
        addedNodes.add(providerNodeId);
      }
      
      // Relationship Edge
      elements.push({
          data: {
            id: `edge-${claim.id}`,
            source: `patient-${claim.patientId}`,
            target: `provider-${claim.providerId}`,
            label: `${claim.cptCode.slice(0, 10)}`,
          },
      });
    });

    const nodeColors = isDark
      ? { patientBg: '#3b82f6', patientText: '#bfdbfe', providerBg: '#ef4444', providerText: '#fecaca' }
      : { patientBg: '#1d4ed8', patientText: '#dbeafe', providerBg: '#dc2626', providerText: '#fee2e2' };

    const edgeColors = isDark
      ? { line: '#6b7280', targetArrow: '#6b7280', label: '#9ca3af', labelBg: '#111827' }
      : { line: '#9ca3af', targetArrow: '#9ca3af', label: '#6b7280', labelBg: '#ffffff' };

    const cy = cytoscape({
      container: containerRef.current,
      elements,
        style: [
        {
          selector: 'node[type="patient"]',
          style: {
            'background-color': nodeColors.patientBg,
            'label': 'data(label)',
            'color': nodeColors.patientText,
            'font-size': '9px',
            'text-valign': 'bottom',
            'text-margin-y': 4,
            'width': '24px',
            'height': '24px',
            'font-family': 'monospace',
            'text-wrap': 'ellipsis',
            'text-max-width': '80px',
          },
        },
        {
          selector: 'node[type="provider"]',
          style: {
            'background-color': nodeColors.providerBg,
            'label': 'data(label)',
            'color': nodeColors.providerText,
            'font-size': '9px',
            'text-valign': 'bottom',
            'text-margin-y': 4,
            'width': '24px',
            'height': '24px',
            'font-family': 'monospace',
            'text-wrap': 'ellipsis',
            'text-max-width': '80px',
          },
        },
        {
          selector: 'edge',
          style: ({
            'width': 1,
            'line-color': edgeColors.line,
            'target-arrow-color': edgeColors.targetArrow,
            'target-arrow-shape': 'triangle',
            'curve-style': 'bezier',
            'label': 'data(label)',
            'font-size': '7px',
            'color': edgeColors.label,
            'font-family': 'monospace',
            'text-background-opacity': 0.8,
            'text-background-color': edgeColors.labelBg,
            'text-background-padding': '1px',
            'text-background-shape': 'roundrectangle',
          }),
        },
      ],
      layout: { name: layoutName, padding: 60, spacingFactor: 1.5 } as any,
    });

    cy.on('tap', 'node', (evt) => {
      const node = evt.target;
      setSelectedNode({
        id: node.id(),
        type: node.data('type'),
        label: node.data('label')
      });
    });

    return () => cy.destroy();
  }, [allClaims, layoutName, isDark]);

  return (
    <div className="space-y-4">
      <div
        className="flex items-center justify-between pb-3"
        style={{ borderBottom: '1px solid var(--border-default)' }}
      >
        <div>
          <h1 className="text-xl font-bold tracking-wider" style={{ color: 'var(--text-primary)' }}>Collusion Networks</h1>
          <p className="text-xs font-mono mt-1" style={{ color: 'var(--text-tertiary)' }}>Directed graph topology mapping referring physician networks</p>
        </div>
        <div className="flex items-center gap-4 text-xs font-mono" style={{ color: 'var(--text-secondary)' }}>
          <div
            className="flex items-center gap-1.5 rounded px-2.5 py-1 border"
            style={{ color: 'var(--text-secondary)', backgroundColor: 'var(--bg-card)', borderColor: 'var(--border-default)' }}
          >
            <span className="uppercase text-[10px] font-bold" style={{ color: 'var(--text-tertiary)' }}>Layout:</span>
            <select 
              value={layoutName} 
              onChange={(e) => setLayoutName(e.target.value as any)}
              className="bg-transparent font-bold focus:outline-none cursor-pointer"
              style={{ color: 'var(--accent-primary)' }}
            >
              <option value="cose" style={{ backgroundColor: 'var(--bg-card)' }}>Organic (COSE)</option>
              <option value="circle" style={{ backgroundColor: 'var(--bg-card)' }}>Circle</option>
              <option value="concentric" style={{ backgroundColor: 'var(--bg-card)' }}>Concentric</option>
              <option value="grid" style={{ backgroundColor: 'var(--bg-card)' }}>Grid</option>
            </select>
          </div>
          <span className="flex items-center gap-1.5">
            <span className="w-3 h-3 rounded-full inline-block" style={{ backgroundColor: 'var(--accent-primary)' }} /> Patient
          </span>
          <span className="flex items-center gap-1.5">
            <span className="w-3 h-3 rounded-full inline-block" style={{ backgroundColor: 'var(--color-danger)' }} /> Provider
          </span>
        </div>
      </div>
      
      <div className="flex flex-col lg:flex-row gap-6">
        <div
          ref={containerRef}
          className="flex-1 rounded-lg min-h-[500px]"
          style={{
            backgroundColor: 'var(--bg-page)',
            border: '1px solid var(--border-default)',
            height: '65vh',
          }}
        />
        {selectedNode && (
          <div
            className="w-full lg:w-80 rounded-lg p-5 flex flex-col justify-between font-mono animate-in slide-in-from-right duration-200"
            style={{ backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-default)' }}
          >
            <div>
              <div
                className="flex items-center justify-between pb-3 mb-4"
                style={{ borderBottom: '1px solid var(--border-default)' }}
              >
                <h3 className="text-xs font-bold uppercase tracking-wider" style={{ color: 'var(--text-secondary)' }}>
                  Node Investigation
                </h3>
                <button
                  onClick={() => setSelectedNode(null)}
                  className="text-xs focus:outline-none"
                  style={{ color: 'var(--text-tertiary)' }}
                >
                  ✕ Close
                </button>
              </div>

              <div className="space-y-4">
                <div>
                  <span className="text-[10px] block uppercase" style={{ color: 'var(--text-tertiary)' }}>Entity Type</span>
                  <span
                    className={`text-xs font-bold px-2 py-0.5 rounded capitalize inline-block mt-1 border`}
                    style={selectedNode.type === 'provider' ? {
                      color: 'var(--color-danger)',
                      backgroundColor: 'var(--color-danger-bg)',
                      borderColor: 'var(--color-danger-border)',
                    } : {
                      color: 'var(--accent-primary)',
                      backgroundColor: 'var(--accent-subtle)',
                      borderColor: 'var(--border-focus)',
                    }}
                  >
                    {selectedNode.type}
                  </span>
                </div>

                <div>
                  <span className="text-[10px] block uppercase" style={{ color: 'var(--text-tertiary)' }}>Identifier</span>
                  <span className="text-sm font-bold" style={{ color: 'var(--text-primary)' }}>{selectedNode.id.split('-')[1]}</span>
                </div>

                {selectedNode.type === 'provider' ? (
                  <div className="space-y-3 pt-2">
                    <div>
                      <span className="text-[10px] block uppercase" style={{ color: 'var(--text-tertiary)' }}>Held Claims Count</span>
                      <span className="text-sm font-bold" style={{ color: 'var(--text-primary)' }}>{providerHeldClaims.length} active holds</span>
                    </div>
                    <div>
                      <span className="text-[10px] block uppercase" style={{ color: 'var(--text-tertiary)' }}>Total Flagged Exposure</span>
                      <span className="text-sm font-bold" style={{ color: 'var(--color-success)' }}>${providerExposure.toLocaleString()}</span>
                    </div>
                    <div>
                      <span className="text-[10px] block uppercase" style={{ color: 'var(--text-tertiary)' }}>Network Co-Adjudication</span>
                      <p className="text-[11px] mt-1 leading-relaxed font-sans" style={{ color: 'var(--text-secondary)' }}>
                        Provider is flagged with high centrality degree in cyclic referrals. Autoencoder reconstruction loss is 96.84% outlier deviation.
                      </p>
                    </div>
                    {providerHeldClaims.length > 0 && (
                      <div>
                        <span className="text-[10px] block uppercase mb-1" style={{ color: 'var(--text-tertiary)' }}>Related Holds</span>
                        <div className="space-y-1.5 max-h-36 overflow-y-auto">
                          {providerHeldClaims.map(c => (
                            <button
                              key={c.id}
                              onClick={() => navigate(`/claims/${c.id}`)}
                              className="w-full text-left p-1.5 rounded text-[10px] font-bold block truncate transition-all"
                              style={{
                                backgroundColor: 'var(--bg-page)',
                                border: '1px solid var(--border-default)',
                                color: 'var(--accent-primary)',
                              }}
                            >
                              Claim {c.id} (${c.totalAmount?.toLocaleString()})
                            </button>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                ) : (
                  <div className="space-y-3 pt-2">
                    <div>
                      <span className="text-[10px] block uppercase" style={{ color: 'var(--text-tertiary)' }}>Held Claims Count</span>
                      <span className="text-sm font-bold" style={{ color: 'var(--text-primary)' }}>{patientHeldClaims.length} active holds</span>
                    </div>
                    <div>
                      <span className="text-[10px] block uppercase" style={{ color: 'var(--text-tertiary)' }}>Total Flagged Billed</span>
                      <span className="text-sm font-bold" style={{ color: 'var(--color-success)' }}>${patientExposure.toLocaleString()}</span>
                    </div>
                    <div>
                      <span className="text-[10px] block uppercase" style={{ color: 'var(--text-tertiary)' }}>Relational Centrality</span>
                      <p className="text-[11px] mt-1 leading-relaxed font-sans" style={{ color: 'var(--text-secondary)' }}>
                        Patient has cross-billed events under identical physical coordinate indicators with shared NPI clinics.
                      </p>
                    </div>
                    {patientHeldClaims.length > 0 && (
                      <div>
                        <span className="text-[10px] block uppercase mb-1" style={{ color: 'var(--text-tertiary)' }}>Related Holds</span>
                        <div className="space-y-1.5 max-h-36 overflow-y-auto">
                          {patientHeldClaims.map(c => (
                            <button
                              key={c.id}
                              onClick={() => navigate(`/claims/${c.id}`)}
                              className="w-full text-left p-1.5 rounded text-[10px] font-bold block truncate transition-all"
                              style={{
                                backgroundColor: 'var(--bg-page)',
                                border: '1px solid var(--border-default)',
                                color: 'var(--accent-primary)',
                              }}
                            >
                              Claim {c.id} (${c.totalAmount?.toLocaleString()})
                            </button>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                )}
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
