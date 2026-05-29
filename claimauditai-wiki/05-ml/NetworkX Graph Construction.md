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
- **Graph Type**: Directed Graph (`nx.DiGraph`).
- **Node Attributes**: `type` (provider/patient/address), `address`, `specialty`.
- **Fraud Detection Cycles**: Identified using NetworkX cycle-finding algorithms (`nx.simple_cycles`).

## See Also
[[Tier 3 - Collusion Network Mapper]] · [[Embedded Python in IRIS]] · [[Dynamic Threshold Logic]]