# Collusion Graph Performance Degradation

> **Symptom:** The collusion network graph endpoint (`/api/graph`) hangs or times out as more claims are added to the system. The Tier 3 audit check becomes progressively slower.

## Root Causes

### 1. Unbounded Cycle Detection
`nx.simple_cycles(G)` has **exponential worst-case complexity** — O((n+e)(c+1)) where `c` is the number of cycles. For a production graph with hundreds of nodes, this can run indefinitely.

### 2. Graph Rebuilt Per Claim
`check_collusion_network()` called `build_relational_graph()` on every single claim audit, rebuilding the entire graph from the database each time.

### 3. State Extraction Fragility
Address state extraction used `split(",")[-1]` which fails when addresses don't have a comma before the state code.

## Fixes

### 1. Bounded cycle detection
```python
cycles = list(nx.simple_cycles(G, length_bound=5))
```
Limits cycles to maximum length 5, capping the exponential search space.

### 2. Additional insight types
Added three new anomaly detection patterns to `export_graph_for_ui()`:
- **Address collisions**: Different NPIs registered at the same physical address
- **Geo-temporal leaps**: Patient billed in different states on the same day
- **High-degree providers**: Providers with 3+ unique patients

All insights now include `claimIds` and `providerId` fields for flagged node/edge highlighting in the Cytoscape graph.

### 3. Robust state extraction
```python
parts = addr.strip().split()
st = parts[-1][:2].upper() if parts and len(parts[-1]) >= 2 else ""
```
Splits by whitespace instead of commas, taking the last token as the state abbreviation.

## Affected Files
- `src/python/graph_analyzer.py` — `check_collusion_network()`, `export_graph_for_ui()`

## Verification
The graph should load within seconds even with 50+ claims. Anomaly insights should include address collisions for providers sharing the same address.
