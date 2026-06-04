import sys
import time
import threading
import networkx as nx

try:
    import iris
except ImportError:
    iris = None

# Module-level graph cache with TTL to avoid rebuilding on every claim audit
_graph_cache = {"graph": None, "timestamp": 0, "ttl": 30}
_graph_lock = threading.Lock()

def build_relational_graph() -> nx.MultiDiGraph:
    """Query IRIS database relations and construct a NetworkX MultiDiGraph representing entity connections.
    MultiDiGraph prevents duplicate edge overwrites between the same patient-provider pair.
    When running outside IRIS (iris module unavailable), returns an empty graph — no mock data."""
    G = nx.MultiDiGraph()
    if not iris:
        return G

    try:
        # Populate DiGraph using Dynamic SQL from FHIR SQL Builder projected tables
        # Let's query Practitioners, Patients, and Claims
        # Node Type 1: Patient
        # Node Type 2: Practitioner (with address attributes)
        
        # 1. Fetch Patients
        stmt = iris.sql.prepare("SELECT Key, Name FROM ClaimAudit.PatientProjections")
        rs = stmt.execute()
        for row in rs:
            G.add_node(str(row[0]), type="patient", name=str(row[1]))
            
        # 2. Fetch Providers (Practitioners) and their addresses
        stmt = iris.sql.prepare("SELECT NPI, Name, AddressLine FROM ClaimAudit.ProviderProjections")
        rs = stmt.execute()
        for row in rs:
            G.add_node(str(row[0]), type="provider", name=str(row[1]), address=str(row[2]).lower().strip())
            
        # 3. Fetch Claim edges
        stmt = iris.sql.prepare("SELECT PatientKey, ProviderNPI, BilledAmount, ServiceDate FROM ClaimAudit.ClaimProjections")
        rs = stmt.execute()
        claim_count = 0
        for row in rs:
            p_key = str(row[0])
            npi = str(row[1])
            amount = float(row[2])
            date = str(row[3])
            
            # Make sure nodes are added if not registered
            if not G.has_node(p_key):
                G.add_node(p_key, type="patient")
            if not G.has_node(npi):
                G.add_node(npi, type="provider", address="")
                
            G.add_edge(p_key, npi, transaction="claim", amount=amount, date=date)
            claim_count += 1

        return G
    except Exception as e:
        sys.stderr.write(f"Graph Construction Error: {str(e)}\n")
        return G

# US state abbreviations for validation
_VALID_STATES = {
    "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
    "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
    "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
    "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
    "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY",
    "DC", "PR", "VI", "GU", "AS", "MP",
}


def _extract_state(address: str) -> str:
    """Extract a 2-letter US state code from an address string."""
    if not address:
        return ""
    parts = address.strip().upper().split()
    for part in reversed(parts):
        if len(part) == 2 and part in _VALID_STATES:
            return part
    last = parts[-1]
    if len(last) >= 2 and last[:2] in _VALID_STATES:
        return last[:2]
    return ""


def _get_cached_graph(force_rebuild: bool = False) -> nx.MultiDiGraph:
    """Get the relational graph from cache or rebuild if TTL expired."""
    with _graph_lock:
        now = time.time()
        if not force_rebuild and _graph_cache["graph"] is not None and (now - _graph_cache["timestamp"]) < _graph_cache["ttl"]:
            return _graph_cache["graph"]
        G = build_relational_graph()
        _graph_cache["graph"] = G
        _graph_cache["timestamp"] = now
        return G

def invalidate_graph_cache():
    """Force graph rebuild on next call — call after data changes."""
    with _graph_lock:
        _graph_cache["graph"] = None
        _graph_cache["timestamp"] = 0

def check_collusion_network(patient_id: str, provider_npi: str, service_date: str) -> dict:
    """Analyze transaction graph topologies to identify address overlaps, geo-temporal leaps, and kickback rings."""
    try:
        G = _get_cached_graph()
        flagged = False
        findings = []
        
        # Verification 1: Address Collision (Unrelated providers sharing physical billing address)
        # Check current provider address
        current_address = G.nodes.get(provider_npi, {}).get("address", "")
        if current_address and current_address != "":
            address_peers = []
            for node, attrs in G.nodes(data=True):
                if attrs.get("type") == "provider" and node != provider_npi:
                    if attrs.get("address") == current_address:
                        address_peers.append(node)
            if len(address_peers) > 0:
                flagged = True
                findings.append(
                    f"Address Collision Warning: Provider shares physical office address ({current_address}) "
                    f"with other distinct billing NPIs ({', '.join(address_peers)}). Potential shell clinic/collusion ring."
                )
                
        # Verification 2: Geo-Temporal Anomaly (Claims for the same patient at dispersed locations on the same day)
        # Check all claims submitted for this patient on this day
        if G.has_node(patient_id):
            patient_claims = []
            for neighbor in G.neighbors(patient_id):
                edge_dict = G.get_edge_data(patient_id, neighbor)
                # MultiDiGraph returns {edge_key: edge_attrs, ...}
                if edge_dict:
                    edge_data = next(iter(edge_dict.values()))
                    if edge_data.get("date") == service_date and neighbor != provider_npi:
                        patient_claims.append(neighbor)
            
            # If the patient has claims at multiple providers on the exact same day
            if len(patient_claims) > 0:
                # Compare provider addresses
                prov1_addr = G.nodes.get(provider_npi, {}).get("address", "")
                for other_npi in patient_claims:
                    prov2_addr = G.nodes.get(other_npi, {}).get("address", "")
                    
                    # If addresses are completely different, assume a geo-temporal impossibility (e.g. Miami vs Seattle)
                    # We can do a basic string state/city match or distance calculation
                    # Let's check states (e.g. "FL" vs "WA") in address
                    state1 = _extract_state(prov1_addr)
                    state2 = _extract_state(prov2_addr)
                    
                    if state1 and state2 and state1 != state2:
                        flagged = True
                        findings.append(
                            f"Geo-Temporal Leap Impossibility: Patient '{patient_id}' has concurrent claims "
                            f"on {service_date} from provider {provider_npi} ({prov1_addr}) and provider {other_npi} "
                            f"({prov2_addr}). Geographically impossible same-day treatments."
                        )

        # Verification 3: Referral Ring Cycle Analysis (undirected bipartite cycle detection)
        try:
            undirected_G = nx.Graph(G)
            cycles = nx.cycle_basis(undirected_G)
        except Exception:
            cycles = []
        for cycle in cycles:
            # Bipartite cycles must contain at least 4 nodes (alternating Patient-Provider)
            if len(cycle) >= 4 and (provider_npi in cycle or patient_id in cycle):
                providers_in_cycle = [n for n in cycle if G.nodes[n].get("type") == "provider"]
                patients_in_cycle = [n for n in cycle if G.nodes[n].get("type") == "patient"]
                
                # A steering cycle requires at least 2 distinct providers sharing patients
                if len(providers_in_cycle) > 1:
                    flagged = True
                    cycle_str = " - ".join(cycle)
                    findings.append(
                        f"Structured steering circle identified (undirected collusion loop): "
                        f"Shared patient loop between providers [{', '.join(providers_in_cycle)}] "
                        f"and patients [{', '.join(patients_in_cycle)}]. "
                        f"Relational loop: {cycle_str}. Suspicion of systematic patient steering or collusion."
                    )

        reason = ""
        if flagged:
            reason = " | ".join(findings)
            
        return {
            "flagged": flagged,
            "findings": findings,
            "reason": reason
        }
        
    except Exception as e:
        # Log the error clearly but NEVER silently return flagged=False for internal errors.
        # Silent suppression hides real anomalies and masks infrastructure failures.
        # Instead, flag the claim for manual review with full error context.
        sys.stderr.write(f"CRITICAL: Graph analysis error in check_collusion_network: {str(e)}\n")
        return {
            "flagged": True,
            "findings": [f"Graph analysis infrastructure error: {str(e)}"],
            "reason": f"Tier 3 (Graph) encountered an internal error: {str(e)}. Claim requires manual adjudication review."
        }

def export_graph_for_ui() -> str:
    """
    Build the full collusion network from FHIR data and export
    as a JSON structure suitable for Cytoscape.js rendering.
    Returns a JSON string with {nodes, edges, insights} structure.
    """
    import json

    G = _get_cached_graph()
    nodes = []
    edges = []
    insights = []

    seen_nodes = set()
    for node, attrs in G.nodes(data=True):
        ntype = attrs.get("type", "patient")
        nid = f"{ntype}-{node}"
        if nid not in seen_nodes:
            seen_nodes.add(nid)
            label = attrs.get("name", str(node))
            entry = {"data": {"id": nid, "label": label, "type": ntype}}
            if ntype == "provider" and attrs.get("address"):
                entry["data"]["address"] = attrs["address"]
            nodes.append(entry)

    seen_edges = set()
    for src, dst, data in G.edges(data=True):
        src_type = G.nodes[src].get("type", "patient")
        dst_type = G.nodes[dst].get("type", "provider")
        eid = f"edge-{src}-{dst}"
        if eid not in seen_edges:
            seen_edges.add(eid)
            edges.append({
                "data": {
                    "id": eid,
                    "source": f"{src_type}-{src}",
                    "target": f"{dst_type}-{dst}",
                    "label": data.get("transaction", "claim"),
                    "amount": data.get("amount", 0.0),
                    "date": data.get("date", ""),
                }
            })

    # Detect temporal impossibilities from edge data
    patient_dates = {}
    for src, dst, data in G.edges(data=True):
        src_type = G.nodes[src].get("type", "patient")
        if src_type == "patient":
            pat = src
            svc_date = data.get("date", "")
            prov = dst
            if pat not in patient_dates:
                patient_dates[pat] = {}
            if svc_date not in patient_dates[pat]:
                patient_dates[pat][svc_date] = []
            patient_dates[pat][svc_date].append((prov, src, dst))

    for patient, dates in patient_dates.items():
        for date, prov_edges in dates.items():
            unique_provs = list(set(p for p, _, _ in prov_edges))
            if len(unique_provs) > 1:
                claim_ids = [f"edge-{s}-{d}" for _, s, d in prov_edges]
                insights.append({
                    "type": "temporal_impossibility",
                    "severity": "critical",
                    "message": f"Patient billed by {len(unique_provs)} different providers on {date}: {', '.join(unique_provs)}",
                    "date": date,
                    "patient": patient,
                    "providerId": f"provider-{unique_provs[0]}",
                    "claimIds": claim_ids,
                })

    # Detect address collisions (different NPIs registered at same address)
    addr_npi_map = {}
    for node, attrs in G.nodes(data=True):
        if attrs.get("type") == "provider" and attrs.get("address"):
            addr = attrs["address"].strip().lower()
            if addr not in addr_npi_map:
                addr_npi_map[addr] = []
            addr_npi_map[addr].append(node)

    for addr, npis in addr_npi_map.items():
        unique_npis = list(set(npis))
        if len(unique_npis) > 1:
            insights.append({
                "type": "address_collision",
                "severity": "critical",
                "message": f"Address collision: {len(unique_npis)} providers registered at same address: {' '.join(unique_npis)}",
                "patient": unique_npis[0],
                "providerId": f"provider-{unique_npis[0]}",
                "claimIds": [f"provider-{n}" for n in unique_npis],
            })

    # Detect geo-temporal anomalies (same patient, different states, same day)
    for patient, dates in patient_dates.items():
        for date, prov_edges in dates.items():
            unique_provs = list(set(p for p, _, _ in prov_edges))
            if len(unique_provs) > 1:
                states = set()
                for p in unique_provs:
                    addr = G.nodes.get(p, {}).get("address", "")
                    st = _extract_state(addr)
                    if st:
                        states.add(st)
                if len(states) > 1:
                    claim_ids = [f"edge-{s}-{d}" for _, s, d in prov_edges]
                    insights.append({
                        "type": "geo_temporal_leap",
                        "severity": "high",
                        "message": f"Geo-temporal anomaly: Patient billed in {', '.join(states)} on same day ({date})",
                        "date": date,
                        "patient": patient,
                        "providerId": f"provider-{unique_provs[0]}",
                        "claimIds": claim_ids,
                    })

    # Detect high-degree providers (too many unique patients)
    prov_patient_count = {}
    for src, dst in G.edges():
        if G.nodes[dst].get("type") == "provider":
            prov_patient_count.setdefault(dst, set()).add(src)
    for prov, patients in prov_patient_count.items():
        if len(patients) >= 10:
            insights.append({
                "type": "high_degree_provider",
                "severity": "high",
                "message": f"High-degree provider: {prov} has {len(patients)} unique patients",
                "patient": min(patients),
                "providerId": f"provider-{prov}",
                "claimIds": [f"edge-{p}-{prov}" for p in patients],
            })

    return json.dumps({
        "nodes": nodes,
        "edges": edges,
        "insights": insights,
        "nodeCount": len(nodes),
        "edgeCount": len(edges),
        "insightCount": len(insights),
    })
