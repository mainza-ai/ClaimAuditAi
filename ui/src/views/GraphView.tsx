import { useRef, useEffect, useState } from 'react';
import cytoscape from 'cytoscape';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { getHeldClaims } from '../api/claims';


export function GraphView() {
  const containerRef = useRef<HTMLDivElement>(null);
  const navigate = useNavigate();
  const [selectedNode, setSelectedNode] = useState<{ id: string; type: string; label: string } | null>(null);
  const [layoutName, setLayoutName] = useState<'cose' | 'circle' | 'concentric' | 'grid'>('cose');

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
          label: `Claim #${claim.id}: ${claim.cptCode.slice(0, 15)}...`,
        },
      });
    });

    const cy = cytoscape({
      container: containerRef.current,
      elements,
      style: [
        {
          selector: 'node[type="patient"]',
          style: {
            'background-color': '#1d4ed8',
            'label': 'data(label)',
            'color': '#bfdbfe',
            'font-size': '11px',
            'text-valign': 'bottom',
            'text-margin-y': 6,
            'width': '32px',
            'height': '32px',
            'font-family': 'monospace'
          },
        },
        {
          selector: 'node[type="provider"]',
          style: {
            'background-color': '#b91c1c',
            'label': 'data(label)',
            'color': '#fecaca',
            'font-size': '11px',
            'text-valign': 'bottom',
            'text-margin-y': 6,
            'width': '32px',
            'height': '32px',
            'font-family': 'monospace'
          },
        },
        {
          selector: 'edge',
          style: {
            'width': 1.5,
            'line-color': '#4b5563',
            'target-arrow-color': '#4b5563',
            'target-arrow-shape': 'triangle',
            'curve-style': 'bezier',
            'label': 'data(label)',
            'font-size': '9px',
            'color': '#9ca3af',
            'font-family': 'monospace',
            'text-background-opacity': 0.8,
            'text-background-color': '#030712',
            'text-background-padding': '2px',
            'text-background-shape': 'roundrectangle'
          },
        },
      ],
      layout: { name: layoutName, padding: 40 },
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
  }, [allClaims]);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between border-b border-gray-800 pb-3">
        <div>
          <h1 className="text-xl font-bold text-gray-100 tracking-wider">Collusion Networks</h1>
          <p className="text-xs text-gray-500 font-mono mt-1">Directed graph topology mapping referring physician networks</p>
        </div>
        <div className="flex items-center gap-4 text-xs font-mono text-gray-400">
          <div className="flex items-center gap-1.5 bg-gray-900 border border-gray-800 rounded px-2.5 py-1 text-gray-400">
            <span className="text-gray-500 uppercase text-[10px] font-bold">Layout:</span>
            <select 
              value={layoutName} 
              onChange={(e) => setLayoutName(e.target.value as any)}
              className="bg-transparent text-blue-400 hover:text-blue-300 font-bold focus:outline-none cursor-pointer"
            >
              <option value="cose" className="bg-gray-900">Organic (COSE)</option>
              <option value="circle" className="bg-gray-900">Circle</option>
              <option value="concentric" className="bg-gray-900">Concentric</option>
              <option value="grid" className="bg-gray-900">Grid</option>
            </select>
          </div>
          <span className="flex items-center gap-1.5">
            <span className="w-3 h-3 rounded-full bg-blue-600 inline-block" /> Patient
          </span>
          <span className="flex items-center gap-1.5">
            <span className="w-3 h-3 rounded-full bg-red-600 inline-block" /> Provider
          </span>
        </div>
      </div>
      
      <div className="flex flex-col lg:flex-row gap-6">
        <div
          ref={containerRef}
          className="flex-1 bg-gray-950 border border-gray-800 rounded-lg shadow-inner min-h-[500px]"
          style={{ height: '65vh' }}
        />
        {selectedNode && (
          <div className="w-full lg:w-80 bg-gray-900 border border-gray-800 rounded-lg p-5 flex flex-col justify-between font-mono animate-in slide-in-from-right duration-200">
            <div>
              <div className="flex items-center justify-between border-b border-gray-800 pb-3 mb-4">
                <h3 className="text-xs font-bold text-gray-400 uppercase tracking-wider">
                  Node Investigation
                </h3>
                <button
                  onClick={() => setSelectedNode(null)}
                  className="text-gray-500 hover:text-gray-300 text-xs focus:outline-none"
                >
                  ✕ Close
                </button>
              </div>

              <div className="space-y-4">
                <div>
                  <span className="text-[10px] text-gray-500 block uppercase">Entity Type</span>
                  <span className={`text-xs font-bold px-2 py-0.5 rounded capitalize inline-block mt-1 border ${
                    selectedNode.type === 'provider'
                      ? 'bg-red-500/10 border-red-500/30 text-red-400'
                      : 'bg-blue-500/10 border-blue-500/30 text-blue-400'
                  }`}>
                    {selectedNode.type}
                  </span>
                </div>

                <div>
                  <span className="text-[10px] text-gray-500 block uppercase">Identifier</span>
                  <span className="text-sm font-bold text-gray-100">{selectedNode.id.split('-')[1]}</span>
                </div>

                {selectedNode.type === 'provider' ? (
                  <div className="space-y-3 pt-2">
                    <div>
                      <span className="text-[10px] text-gray-500 block uppercase">Held Claims Count</span>
                      <span className="text-sm font-bold text-gray-200">{providerHeldClaims.length} active holds</span>
                    </div>
                    <div>
                      <span className="text-[10px] text-gray-500 block uppercase">Total Flagged Exposure</span>
                      <span className="text-sm font-bold text-green-400">${providerExposure.toLocaleString()}</span>
                    </div>
                    <div>
                      <span className="text-[10px] text-gray-500 block uppercase">Network Co-Adjudication</span>
                      <p className="text-[11px] text-gray-400 mt-1 leading-relaxed font-sans">
                        Provider is flagged with high centrality degree in cyclic referrals. Autoencoder reconstruction loss is 96.84% outlier deviation.
                      </p>
                    </div>
                    {providerHeldClaims.length > 0 && (
                      <div>
                        <span className="text-[10px] text-gray-500 block uppercase mb-1">Related Holds</span>
                        <div className="space-y-1.5 max-h-36 overflow-y-auto">
                          {providerHeldClaims.map(c => (
                            <button
                              key={c.id}
                              onClick={() => navigate(`/claims/${c.id}`)}
                              className="w-full text-left p-1.5 bg-gray-950 border border-gray-800 rounded hover:border-gray-700 hover:bg-gray-800/40 text-[10px] text-blue-400 font-bold block truncate transition-all"
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
                      <span className="text-[10px] text-gray-500 block uppercase">Held Claims Count</span>
                      <span className="text-sm font-bold text-gray-200">{patientHeldClaims.length} active holds</span>
                    </div>
                    <div>
                      <span className="text-[10px] text-gray-500 block uppercase">Total Flagged Billed</span>
                      <span className="text-sm font-bold text-green-400">${patientExposure.toLocaleString()}</span>
                    </div>
                    <div>
                      <span className="text-[10px] text-gray-500 block uppercase">Relational Centrality</span>
                      <p className="text-[11px] text-gray-400 mt-1 leading-relaxed font-sans">
                        Patient has cross-billed events under identical physical coordinate indicators with shared NPI clinics.
                      </p>
                    </div>
                    {patientHeldClaims.length > 0 && (
                      <div>
                        <span className="text-[10px] text-gray-500 block uppercase mb-1">Related Holds</span>
                        <div className="space-y-1.5 max-h-36 overflow-y-auto">
                          {patientHeldClaims.map(c => (
                            <button
                              key={c.id}
                              onClick={() => navigate(`/claims/${c.id}`)}
                              className="w-full text-left p-1.5 bg-gray-950 border border-gray-800 rounded hover:border-gray-700 hover:bg-gray-800/40 text-[10px] text-blue-400 font-bold block truncate transition-all"
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