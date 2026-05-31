import { useRef, useEffect, useState } from 'react';
import cytoscape from 'cytoscape';
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../api/client';
import { useThemeStore } from '../store/themeStore';
import type { GraphData, GraphInsight } from '../types/graph';
import { AlertTriangle, Network, Users, Building2 } from 'lucide-react';

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

export function GraphView() {
  const containerRef = useRef<HTMLDivElement>(null);
  const { theme } = useThemeStore();
  const [selectedNode, setSelectedNode] = useState<{ id: string; label: string; type: string } | null>(null);
  const [layout, setLayout] = useState<'cose' | 'circle' | 'grid'>('cose');

  const { data: graph, isLoading, isError } = useQuery<GraphData>({
    queryKey: ['graph'],
    queryFn: () => apiClient.get('/graph').then(r => r.data),
    refetchInterval: 30000,
  });

  const isDark = theme === 'dark';

  useEffect(() => {
    if (!containerRef.current || !graph?.nodes?.length) return;

    const cy = cytoscape({
      container: containerRef.current,
      elements: [...graph.nodes, ...graph.edges],
      style: [
        {
          selector: 'node[type="provider"]',
          style: {
            'background-color': isDark ? '#1d4ed8' : '#0067B8',
            'border-width': 2,
            'border-color': isDark ? '#3b82f6' : '#004f8c',
            'label': 'data(label)',
            'color': isDark ? '#e0f2fe' : '#1A1A1A',
            'font-size': '11px',
            'font-family': 'DM Sans, system-ui, sans-serif',
            'text-valign': 'bottom',
            'text-margin-y': 6,
            'width': 36,
            'height': 36,
            'text-wrap': 'wrap',
            'text-max-width': '100px',
            'shape': 'roundrectangle',
          },
        },
        {
          selector: 'node[type="patient"]',
          style: {
            'background-color': isDark ? '#374151' : '#F5F7F9',
            'border-width': 2,
            'border-color': isDark ? '#6b7280' : '#CBD5E1',
            'label': 'data(label)',
            'color': isDark ? '#d1d5db' : '#1A1A1A',
            'font-size': '10px',
            'font-family': 'DM Sans, system-ui, sans-serif',
            'text-valign': 'bottom',
            'text-margin-y': 6,
            'width': 28,
            'height': 28,
            'shape': 'ellipse',
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
            'width': 1.5,
            'line-color': isDark ? '#374151' : '#CBD5E1',
            'target-arrow-color': isDark ? '#374151' : '#CBD5E1',
            'target-arrow-shape': 'triangle',
            'curve-style': 'bezier',
            'label': 'data(label)',
            'font-size': '9px',
            'font-family': 'JetBrains Mono, monospace',
            'color': isDark ? '#6b7280' : '#9AA5B4',
            'text-rotation': 'autorotate',
            'text-margin-y': -8,
          },
        },
        {
          selector: 'edge.flagged',
          style: {
            'line-color': isDark ? '#ef4444' : '#C0392B',
            'target-arrow-color': isDark ? '#ef4444' : '#C0392B',
            'width': 2.5,
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
      ],
      layout: { name: layout, padding: 60, animate: true, animationDuration: 400 } as any,
    });

    (graph.insights ?? []).forEach((insight: GraphInsight) => {
      if (insight.severity === 'critical') {
        if (insight.patient) cy.$(`#patient-${insight.patient}`).addClass('flagged');
        if (insight.providerId) cy.$(`#${insight.providerId}`).addClass('flagged');
        insight.claimIds?.forEach(cid => cy.$(`#edge-${cid}`).addClass('flagged'));
      }
    });

    cy.on('tap', 'node', evt => {
      const node = evt.target;
      setSelectedNode({
        id: node.id(),
        label: node.data('label'),
        type: node.data('type'),
      });
    });

    cy.on('tap', evt => {
      if (evt.target === cy) setSelectedNode(null);
    });

    if (containerRef.current) {
      containerRef.current.style.backgroundColor = isDark ? '#030712' : '#F5F7F9';
    }

    return () => cy.destroy();
  }, [graph, theme, layout]);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16, height: '100%' }}>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <h1 style={{ margin: 0, fontSize: 20, fontWeight: 600, color: 'var(--text-primary)' }}>
            Collusion Network
          </h1>
          {graph && (
            <p style={{ margin: '4px 0 0', fontSize: 12, color: 'var(--text-tertiary)' }}>
              {graph.nodeCount} entities \u00b7 {graph.edgeCount} transactions \u00b7 {graph.insightCount} anomalies detected
            </p>
          )}
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          {(['cose', 'circle', 'grid'] as const).map(l => (
            <button
              key={l}
              onClick={() => setLayout(l)}
              style={{
                padding: '5px 12px', borderRadius: 6, textTransform: 'capitalize',
                border: `1px solid ${layout === l ? 'var(--accent-primary)' : 'var(--border-default)'}`,
                backgroundColor: layout === l ? 'var(--accent-subtle)' : 'transparent',
                color: layout === l ? 'var(--accent-text)' : 'var(--text-secondary)',
                fontSize: 12, cursor: 'pointer',
              }}
            >
              {l}
            </button>
          ))}
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
          <span style={{ width: 12, height: 12, borderRadius: '50%', border: '2px solid var(--color-danger)', display: 'inline-block' }} />
          Flagged entity
        </span>
      </div>

      <div style={{ display: 'flex', gap: 16, flex: 1, minHeight: 0 }}>
        {/* Graph canvas */}
        <div style={{ flex: 1, position: 'relative', minHeight: 0 }}>
          {isLoading && (
            <div style={{
              position: 'absolute', inset: 0, display: 'flex', alignItems: 'center',
              justifyContent: 'center', color: 'var(--text-tertiary)', fontSize: 14,
              backgroundColor: 'var(--bg-card)', borderRadius: 8, border: '1px solid var(--border-default)',
            }}>
              Building network graph...
            </div>
          )}
          {isError && (
            <div style={{
              position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column',
              alignItems: 'center', justifyContent: 'center', gap: 8,
              color: 'var(--color-danger)', fontSize: 14,
              backgroundColor: 'var(--bg-card)', borderRadius: 8, border: '1px solid var(--border-default)',
            }}>
              <AlertTriangle size={32} style={{ opacity: 0.5 }} />
              <p style={{ margin: 0 }}>Failed to load collusion graph.</p>
              <p style={{ margin: 0, fontSize: 12 }}>The graph analysis engine may be unavailable.</p>
            </div>
          )}
          {!isLoading && !isError && !graph?.nodes?.length && (
            <div style={{
              position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column',
              alignItems: 'center', justifyContent: 'center', gap: 8,
              color: 'var(--text-tertiary)', fontSize: 14,
              backgroundColor: 'var(--bg-card)', borderRadius: 8, border: '1px solid var(--border-default)',
            }}>
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
        </div>

        {/* Right panel */}
        <div style={{ width: 300, display: 'flex', flexDirection: 'column', gap: 12, overflowY: 'auto' }}>
          {/* AI Insights */}
          <div className="card" style={{ padding: 16 }}>
            <p style={{ margin: '0 0 12px', fontSize: 12, fontWeight: 600, color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.06em' }}>
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
                  style={{
                    padding: 10, borderRadius: 6,
                    border: `1px solid ${insight.severity === 'critical' ? 'var(--color-danger-border)' : insight.severity === 'high' ? 'var(--color-warning-border)' : 'var(--border-default)'}`,
                    backgroundColor: SEVERITY_BG[insight.severity],
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'flex-start', gap: 6, marginBottom: 4 }}>
                    <AlertTriangle size={12} style={{ color: SEVERITY_COLORS[insight.severity], flexShrink: 0, marginTop: 1 }} />
                    <span style={{ fontSize: 10, fontWeight: 700, color: SEVERITY_COLORS[insight.severity], textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                      {insight.severity} \u00b7 {insight.type.replace(/_/g, ' ')}
                    </span>
                  </div>
                  <p style={{ margin: 0, fontSize: 12, color: 'var(--text-primary)', lineHeight: 1.4 }}>
                    {insight.message}
                  </p>
                  {insight.date && (
                    <p style={{ margin: '4px 0 0', fontSize: 11, color: 'var(--text-tertiary)', fontFamily: 'var(--font-mono)' }}>
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
              <p style={{ margin: '0 0 10px', fontSize: 12, fontWeight: 600, color: 'var(--text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.06em' }}>
                Selected Entity
              </p>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
                {selectedNode.type === 'provider' ? <Building2 size={16} color="var(--accent-primary)" /> : <Users size={16} color="var(--text-secondary)" />}
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
        </div>
      </div>
    </div>
  );
}
