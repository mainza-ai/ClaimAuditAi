# NetworkX Graph Construction

> The Referral Graph uses NetworkX to model entities and referrals, detecting organized fraud circles and collusion loops at the transaction layer.

When a claim is submitted, the engine builds an active referral subgraph centered around the patient, submitting provider, and referring doctor. It queries our projected tables to populate the graph:

```python
import networkx as nx

# Create a directed graph to model relationships
G = nx.DiGraph()
G.add_node(provider_npi, type="provider", address=provider_address)
G.add_node(patient_id, type="patient")
G.add_edge(patient_id, provider_npi, relation="billing")
```

The engine traverses the graph using NetworkX to identify anomalous patterns:
1. **Collusion Loops**: Detects cyclic pathways where multiple providers repeatedly refer the same patient cohort to each other.
2. **Geo-Temporal Leaps**: Checks if the patient is billed for services at geographically distant locations on the same day.

## Key Details
- **Library**: `networkx` running natively inside Embedded Python.
- **Graph Type**: Directed Multigraph (`nx.MultiDiGraph`) — supports multiple edges between same patient-provider pairs without overwriting.
- **Node Attributes**: `type` (provider/patient), `address` (provider nodes only), `name`.
- **Fraud Detection Cycles**: Identified using bounded `nx.cycle_basis` on an undirected copy of the graph (max cycle length 5).
- **Caching**: Graph is built once per request (30s TTL) and invalidated after each claim audit so subsequent claims see newly added edges. The persistent `^ClaimAuditGraph` globals are cleared on full data reset via `GraphStore.ClearAll()`.
- **Error Handling**: Exceptions during graph construction or analysis now flag the claim for review (fail-open) rather than silently returning `flagged=False`. No hardcoded mock data remains — empty repositories produce empty graphs.
- **PNG Export**: The UI graph page includes a download button that exports the current visualization as a PNG via Cytoscape.js `cy.png({full: true})`.
- **All-Clear Badge**: When the graph has edges but zero anomalies detected, a green ShieldCheck badge appears in the header — positive feedback instead of silence.

## See Also
[[Tier 3 - Collusion Network Mapper]] · [[Embedded Python in IRIS]] · [[Dynamic Threshold Logic]]