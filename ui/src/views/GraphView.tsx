import { useRef, useEffect, useState, useCallback } from 'react';
import cytoscape from 'cytoscape';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '../api/client';
import { useThemeStore } from '../store/themeStore';
import type { GraphData, GraphInsight } from '../types/graph';
import {
  AlertTriangle,
  Network,
  Users,
  Building2,
  ZoomIn,
  ZoomOut,
  Maximize,
  RefreshCw,
  Download,
  ShieldCheck,
} from 'lucide-react';

const SEVERITY_COLORS: Record<string, string> = {
  critical: 'var(--color-danger)',
  high: 'var(--color-warning)',
  medium: 'var(--text-secondary)',
};

const SEVERITY_BG: Record<string, string> = {
  critical: 'var(--color-danger-bg)',
  high: 'var(--color-warning-bg)',
  medium: 'var(--bg-hover)',
};

function getGraphStyle(isDark: boolean) {
  return [
    {
      selector: 'node[type="provider"]',
      style: {
        'background-color': isDark ? '#1d4ed8' : '#0067B8',
        'border-width': 2,
        'border-color': isDark ? '#3b82f6' : '#004f8c',
        label: 'data(label)',
        color: isDark ? '#e0f2fe' : '#1A1A1A',
        'font-size': '11px',
        'font-family': 'DM Sans, system-ui, sans-serif',
        'text-valign': 'bottom',
        'text-margin-y': 6,
        width: 36,
        height: 36,
        'text-wrap': 'wrap',
        'text-max-width': '100px',
        shape: 'roundrectangle',
      },
    },
    {
      selector: 'node[type="patient"]',
      style: {
        'background-color': isDark ? '#374151' : '#F5F7F9',
        'border-width': 2,
        'border-color': isDark ? '#6b7280' : '#CBD5E1',
        label: 'data(label)',
        color: isDark ? '#d1d5db' : '#1A1A1A',
        'font-size': '10px',
        'font-family': 'DM Sans, system-ui, sans-serif',
        'text-valign': 'bottom',
        'text-margin-y': 6,
        width: 28,
        height: 28,
        shape: 'ellipse',
      },
    },
    {
      selector: 'node.flagged',
      style: {
        'border-color': isDark ? '#ef4444' : '#C0392B',
        'border-width': 3,
        'background-color': isDark ? '#7f1d1d' : '#FEF2F2',
      },
    },
    {
      selector: 'edge',
      style: {
        width: 1.5,
        'line-color': isDark ? '#374151' : '#CBD5E1',
        'target-arrow-color': isDark ? '#374151' : '#CBD5E1',
        'target-arrow-shape': 'triangle',
        'curve-style': 'bezier',
        label: 'data(label)',
        'font-size': '9px',
        'font-family': 'JetBrains Mono, monospace',
        color: isDark ? '#6b7280' : '#9CA3AF',
        'text-rotation': 'autorotate',
        'text-margin-y': -8,
      },
    },
    {
      selector: 'edge.flagged',
      style: {
        'line-color': isDark ? '#ef4444' : '#C0392B',
        'target-arrow-color': isDark ? '#ef4444' : '#C0392B',
        width: 2.5,
        'line-style': 'dashed',
      },
    },
    {
      selector: ':selected',
      style: {
        'border-color': isDark ? '#60a5fa' : '#0067B8',
        'border-width': 3,
      },
    },
  ];
}

export function GraphView() {
  const containerRef = useRef<HTMLDivElement>(null);
  const cyRef = useRef<cytoscape.Core | null>(null);
  const { theme } = useThemeStore();
  const queryClient = useQueryClient();
  const [selectedNode, setSelectedNode] = useState<{ id: string; label: string; type: string } | null>(null);
  const [selectedEdge, setSelectedEdge] = useState<{
    id: string;
    source: string;
    target: string;
    amount: number;
    date: string;
  } | null>(null);
  const [tooltip, setTooltip] = useState<{ text: string; x: number; y: number } | null>(null);
  const [layout, setLayout] = useState<'cose' | 'circle' | 'grid'>('cose');

  const {
    data: graph,
    isLoading,
    isError,
  } = useQuery<GraphData>({
    queryKey: ['graph'],
    queryFn: () => apiClient.get('/graph').then((r) => r.data),
    refetchInterval: 30000,
  });

  const isDark = theme === 'dark';

  // Create or update cytoscape instance when graph data changes
  useEffect(() => {
    if (!containerRef.current || !graph?.nodes?.length) return;

    if (!cyRef.current) {
      const cy = cytoscape({
        container: containerRef.current,
        elements: [...graph.nodes, ...graph.edges],
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        style: getGraphStyle(isDark) as any,
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        layout: { name: layout, padding: 60, animate: true, animationDuration: 400 } as any,
        minZoom: 0.1,
        maxZoom: 3,
      });
      cyRef.current = cy;

      // Flag insight elements
      (graph.insights ?? []).forEach((insight: GraphInsight) => {
        if (insight.severity === 'critical') {
          if (insight.providerId) {
            const el = cy.$(`#${insight.providerId}`);
            if (el.length) el.addClass('flagged');
          }
          insight.claimIds?.forEach((cid) => {
            const el = cy.$(`#${cid}`);
            if (el.length) el.addClass('flagged');
          });
        }
      });

      // Node click handler
      cy.on('tap', 'node', (evt) => {
        const node = evt.target;
        setSelectedEdge(null);
        setSelectedNode({ id: node.id(), label: node.data('label'), type: node.data('type') });
      });

      // Edge click handler — show transaction details
      cy.on('tap', 'edge', (evt) => {
        const edge = evt.target;
        setSelectedNode(null);
        setSelectedEdge({
          id: edge.id(),
          source: edge.data('source'),
          target: edge.data('target'),
          amount: edge.data('amount') || 0,
          date: edge.data('date') || '',
        });
      });

      cy.on('tap', (evt) => {
        if (evt.target === cy) {
          setSelectedNode(null);
          setSelectedEdge(null);
        }
      });

      // Hover tooltips
      cy.on('mouseover', 'node', (evt) => {
        const node = evt.target;
        const pos = node.renderedPosition();
        const addr = node.data('address');
        setTooltip({
          text: addr ? `${node.data('label')}\n${addr}` : node.data('label'),
          x: pos.x,
          y: pos.y - 20,
        });
      });
      cy.on('mouseout', 'node', () => setTooltip(null));
      cy.on('mouseover', 'edge', (evt) => {
        const edge = evt.target;
        const pos = edge.midpoint();
        setTooltip({
          text: `$${(edge.data('amount') || 0).toLocaleString()} · ${edge.data('date')}`,
          x: pos.x,
          y: pos.y - 10,
        });
      });
      cy.on('mouseout', 'edge', () => setTooltip(null));

      // Highlight insight elements on first load
      highlightInsightElements(cy, graph.insights ?? [], false);
    } else {
      // Update elements without recreating instance — replace in place to avoid flicker
      cyRef.current.elements().remove();
      cyRef.current.add([...graph.nodes, ...graph.edges]);
      highlightInsightElements(cyRef.current, graph.insights ?? [], false);
    }
  }, [graph]);

  // Destroy on unmount only (not on every data update)
  useEffect(() => {
    return () => {
      cyRef.current?.destroy();
      cyRef.current = null;
    };
  }, []);

  // Update styles on theme change without recreating instance
  useEffect(() => {
    if (cyRef.current) {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      (cyRef.current.style() as any).fromJson(getGraphStyle(isDark)).update();
    }
  }, [theme]);

  // Update layout without recreating instance
  const applyLayout = useCallback((name: 'cose' | 'circle' | 'grid') => {
    setLayout(name);
    if (cyRef.current) {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      cyRef.current.layout({ name, padding: 60, animate: true, animationDuration: 400 } as any).run();
    }
  }, []);

  const handleZoomIn = () => cyRef.current?.zoom(cyRef.current.zoom() * 1.2);
  const handleZoomOut = () => cyRef.current?.zoom(cyRef.current.zoom() * 0.8);
  const handleFit = () => cyRef.current?.fit(undefined, 20);
  const handleExportPNG = () => {
    if (!cyRef.current) return;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const b64 = (cyRef.current as any).png({ full: true, bg: isDark ? '#0F172A' : '#FFFFFF' });
    const link = document.createElement('a');
    link.download = 'claimaudit-collusion-network.png';
    link.href = b64;
    link.click();
  };

  const highlightInsightElements = (cy: cytoscape.Core, insights: GraphInsight[], flash: boolean) => {
    cy.elements().removeClass('highlighted');
    insights.forEach((insight: GraphInsight) => {
      if (insight.severity === 'critical') {
        if (insight.providerId) {
          const el = cy.$(`#${insight.providerId}`);
          if (el.length) el.addClass('highlighted').addClass('flagged');
        }
        insight.claimIds?.forEach((cid) => {
          const el = cy.$(`#${cid}`);
          if (el.length) el.addClass('highlighted').addClass('flagged');
        });
      }
    });
    if (flash && insights.length > 0) {
      const firstId = insights[0]?.providerId || insights[0]?.claimIds?.[0];
      if (firstId) {
        const el = cy.$(`#${firstId}`);
        if (el.length) {
          cy.animate({ fit: { eles: el, padding: 60 }, duration: 500 });
        }
      }
    }
  };

  const handleInsightClick = (insight: GraphInsight) => {
    if (!cyRef.current) return;
    highlightInsightElements(cyRef.current, [insight], true);
  };

  if (containerRef.current) {
    containerRef.current.style.backgroundColor = isDark ? '#0F172A' : '#F9FAFB';
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16, height: '100%' }}>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <h1 style={{ margin: 0, fontSize: 20, fontWeight: 600, color: 'var(--text-primary)' }}>Collusion Network</h1>
          {graph && (
            <p style={{ margin: '4px 0 0', fontSize: 12, color: 'var(--text-tertiary)' }}>
              {graph.nodeCount} entities \u00b7 {graph.edgeCount} transactions \u00b7 {graph.insightCount} anomalies
              {graph.insightCount === 0 && graph.edgeCount > 0 && (
                <span
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: 4,
                    color: 'var(--color-success)',
                    marginLeft: 6,
                    fontFamily: 'var(--font-mono)',
                    fontWeight: 600,
                    fontSize: 11,
                  }}
                >
                  <ShieldCheck size={12} /> All clear
                </span>
              )}
            </p>
          )}
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          {(['cose', 'circle', 'grid'] as const).map((l) => (
            <button
              key={l}
              onClick={() => applyLayout(l)}
              style={{
                padding: '5px 12px',
                borderRadius: 6,
                textTransform: 'capitalize',
                border: `1px solid ${layout === l ? 'var(--accent-primary)' : 'var(--border-default)'}`,
                backgroundColor: layout === l ? 'var(--accent-subtle)' : 'transparent',
                color: layout === l ? 'var(--accent-text)' : 'var(--text-secondary)',
                fontSize: 12,
                cursor: 'pointer',
              }}
            >
              {l}
            </button>
          ))}
          <div style={{ borderLeft: '1px solid var(--border-default)', marginLeft: 4 }} />
          <button
            onClick={handleZoomIn}
            title="Zoom in"
            style={{
              padding: '5px 8px',
              borderRadius: 6,
              border: '1px solid var(--border-default)',
              backgroundColor: 'transparent',
              cursor: 'pointer',
              color: 'var(--text-secondary)',
            }}
          >
            <ZoomIn size={14} />
          </button>
          <button
            onClick={handleZoomOut}
            title="Zoom out"
            style={{
              padding: '5px 8px',
              borderRadius: 6,
              border: '1px solid var(--border-default)',
              backgroundColor: 'transparent',
              cursor: 'pointer',
              color: 'var(--text-secondary)',
            }}
          >
            <ZoomOut size={14} />
          </button>
          <button
            onClick={handleFit}
            title="Fit to screen"
            style={{
              padding: '5px 8px',
              borderRadius: 6,
              border: '1px solid var(--border-default)',
              backgroundColor: 'transparent',
              cursor: 'pointer',
              color: 'var(--text-secondary)',
            }}
          >
            <Maximize size={14} />
          </button>
          <button
            onClick={() => queryClient.invalidateQueries({ queryKey: ['graph'] })}
            title="Refresh graph"
            style={{
              padding: '5px 8px',
              borderRadius: 6,
              border: '1px solid var(--border-default)',
              backgroundColor: 'transparent',
              cursor: 'pointer',
              color: 'var(--text-secondary)',
            }}
          >
            <RefreshCw size={14} />
          </button>
          <button
            onClick={handleExportPNG}
            title="Export as PNG"
            style={{
              padding: '5px 8px',
              borderRadius: 6,
              border: '1px solid var(--border-default)',
              backgroundColor: 'transparent',
              cursor: 'pointer',
              color: 'var(--text-secondary)',
            }}
          >
            <Download size={14} />
          </button>
        </div>
      </div>

      {/* Legend */}
      <div style={{ display: 'flex', gap: 20, fontSize: 12, color: 'var(--text-secondary)', alignItems: 'center' }}>
        <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <Building2 size={14} color="var(--accent-primary)" /> Provider
        </span>
        <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <Users size={14} color="var(--text-tertiary)" /> Patient
        </span>
        <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{ width: 20, height: 2, backgroundColor: 'var(--color-danger)', display: 'inline-block' }} />
          Flagged transaction
        </span>
        <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <span
            style={{
              width: 12,
              height: 12,
              borderRadius: '50%',
              border: '2px solid var(--color-danger)',
              display: 'inline-block',
            }}
          />
          Flagged entity
        </span>
      </div>

      <div style={{ display: 'flex', gap: 16, flex: 1, minHeight: 0 }}>
        {/* Graph canvas */}
        <div style={{ flex: 1, position: 'relative', minHeight: 0 }}>
          {isLoading && (
            <div
              style={{
                position: 'absolute',
                inset: 0,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: 'var(--text-tertiary)',
                fontSize: 14,
                backgroundColor: 'var(--bg-card)',
                borderRadius: 8,
                border: '1px solid var(--border-default)',
              }}
            >
              Building network graph...
            </div>
          )}
          {isError && (
            <div
              style={{
                position: 'absolute',
                inset: 0,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 8,
                color: 'var(--color-danger)',
                fontSize: 14,
                backgroundColor: 'var(--bg-card)',
                borderRadius: 8,
                border: '1px solid var(--border-default)',
              }}
            >
              <AlertTriangle size={32} style={{ opacity: 0.5 }} />
              <p style={{ margin: 0 }}>Failed to load collusion graph.</p>
              <p style={{ margin: 0, fontSize: 12 }}>The graph analysis engine may be unavailable.</p>
            </div>
          )}
          {!isLoading && !isError && !graph?.nodes?.length && (
            <div
              style={{
                position: 'absolute',
                inset: 0,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 8,
                color: 'var(--text-tertiary)',
                fontSize: 14,
                backgroundColor: 'var(--bg-card)',
                borderRadius: 8,
                border: '1px solid var(--border-default)',
              }}
            >
              <Network size={32} style={{ opacity: 0.3 }} />
              <p style={{ margin: 0 }}>No claim data to graph yet.</p>
              <p style={{ margin: 0, fontSize: 12 }}>Submit claims to see the collusion network.</p>
            </div>
          )}
          <div
            ref={containerRef}
            style={{
              width: '100%',
              height: '60vh',
              borderRadius: 8,
              border: '1px solid var(--border-default)',
              overflow: 'hidden',
            }}
          />
          {tooltip && (
            <div
              style={{
                position: 'absolute',
                left: tooltip.x,
                top: tooltip.y,
                transform: 'translate(-50%, -100%)',
                pointerEvents: 'none',
                zIndex: 100,
                padding: '4px 8px',
                borderRadius: 4,
                backgroundColor: isDark ? '#1E293B' : '#FFFFFF',
                border: '1px solid var(--border-default)',
                fontSize: 11,
                fontFamily: 'var(--font-mono)',
                color: 'var(--text-primary)',
                boxShadow: 'var(--shadow-modal)',
                whiteSpace: 'pre-line',
                maxWidth: 250,
              }}
            >
              {tooltip.text}
            </div>
          )}
        </div>

        {/* Right panel */}
        <div style={{ width: 300, display: 'flex', flexDirection: 'column', gap: 12, overflowY: 'auto' }}>
          {/* AI Insights */}
          <div className="card" style={{ padding: 16 }}>
            <p
              style={{
                margin: '0 0 12px',
                fontSize: 12,
                fontWeight: 600,
                color: 'var(--text-tertiary)',
                textTransform: 'uppercase',
                letterSpacing: '0.06em',
              }}
            >
              AI Anomaly Insights
            </p>
            {!graph?.insights?.length && (
              <p style={{ margin: 0, fontSize: 13, color: 'var(--text-tertiary)' }}>
                No anomalies detected in current network.
              </p>
            )}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {graph?.insights?.map((insight, i) => (
                <div
                  key={i}
                  onClick={() => handleInsightClick(insight)}
                  title="Click to highlight on graph"
                  style={{
                    padding: 10,
                    borderRadius: 6,
                    cursor: 'pointer',
                    border: `1px solid ${insight.severity === 'critical' ? 'var(--color-danger-border)' : insight.severity === 'high' ? 'var(--color-warning-border)' : 'var(--border-default)'}`,
                    backgroundColor: SEVERITY_BG[insight.severity],
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'flex-start', gap: 6, marginBottom: 4 }}>
                    <AlertTriangle
                      size={12}
                      style={{ color: SEVERITY_COLORS[insight.severity], flexShrink: 0, marginTop: 1 }}
                    />
                    <span
                      style={{
                        fontSize: 10,
                        fontWeight: 700,
                        color: SEVERITY_COLORS[insight.severity],
                        textTransform: 'uppercase',
                        letterSpacing: '0.05em',
                      }}
                    >
                      {insight.severity} \u00b7 {insight.type.replace(/_/g, ' ')}
                    </span>
                  </div>
                  <p style={{ margin: 0, fontSize: 12, color: 'var(--text-primary)', lineHeight: 1.4 }}>
                    {insight.message}
                  </p>
                  {insight.date && (
                    <p
                      style={{
                        margin: '4px 0 0',
                        fontSize: 11,
                        color: 'var(--text-tertiary)',
                        fontFamily: 'var(--font-mono)',
                      }}
                    >
                      Date: {insight.date}
                    </p>
                  )}
                </div>
              ))}
            </div>
          </div>

          {/* Selected node detail */}
          {selectedNode && (
            <div className="card" style={{ padding: 16 }}>
              <p
                style={{
                  margin: '0 0 10px',
                  fontSize: 12,
                  fontWeight: 600,
                  color: 'var(--text-tertiary)',
                  textTransform: 'uppercase',
                  letterSpacing: '0.06em',
                }}
              >
                Selected Entity
              </p>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
                {selectedNode.type === 'provider' ? (
                  <Building2 size={16} color="var(--accent-primary)" />
                ) : (
                  <Users size={16} color="var(--text-secondary)" />
                )}
                <span style={{ fontSize: 14, fontWeight: 500, color: 'var(--text-primary)' }}>
                  {selectedNode.label}
                </span>
              </div>
              <p style={{ margin: 0, fontSize: 12, color: 'var(--text-tertiary)', fontFamily: 'var(--font-mono)' }}>
                ID: {selectedNode.id}
              </p>
              <p style={{ margin: '4px 0 0', fontSize: 12, color: 'var(--text-tertiary)' }}>
                Type: {selectedNode.type === 'provider' ? 'Healthcare Provider' : 'Patient'}
              </p>
            </div>
          )}

          {/* Selected edge detail */}
          {selectedEdge && (
            <div className="card" style={{ padding: 16 }}>
              <p
                style={{
                  margin: '0 0 10px',
                  fontSize: 12,
                  fontWeight: 600,
                  color: 'var(--text-tertiary)',
                  textTransform: 'uppercase',
                  letterSpacing: '0.06em',
                }}
              >
                Selected Transaction
              </p>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                <p style={{ margin: 0, fontSize: 12, color: 'var(--text-tertiary)', fontFamily: 'var(--font-mono)' }}>
                  ID: {selectedEdge.id}
                </p>
                <p style={{ margin: 0, fontSize: 14, fontWeight: 600, color: 'var(--text-primary)' }}>
                  ${selectedEdge.amount.toLocaleString()}
                </p>
                <p style={{ margin: 0, fontSize: 12, color: 'var(--text-secondary)' }}>{selectedEdge.date}</p>
                <div style={{ borderTop: '1px solid var(--border-default)', paddingTop: 8, marginTop: 4 }}>
                  <p style={{ margin: 0, fontSize: 11, color: 'var(--text-tertiary)', fontFamily: 'var(--font-mono)' }}>
                    From: {selectedEdge.source}
                  </p>
                  <p
                    style={{
                      margin: '2px 0 0',
                      fontSize: 11,
                      color: 'var(--text-tertiary)',
                      fontFamily: 'var(--font-mono)',
                    }}
                  >
                    To: {selectedEdge.target}
                  </p>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
