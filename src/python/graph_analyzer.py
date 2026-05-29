import sys
import networkx as nx

try:
    import iris
except ImportError:
    iris = None

def build_relational_graph() -> nx.DiGraph:
    """Query IRIS database relations and construct a NetworkX DiGraph representing entity connections."""
    G = nx.DiGraph()
    if not iris:
        # If not running in IRIS, return a pre-populated mock graph for ZPM verification
        # Nodes: Patients, NPIs (Practitioners), Clinics (Addresses)
        G.add_node("Pat_Alice", type="patient")
        G.add_node("Pat_Bob", type="patient")
        G.add_node("NPI_12345", type="provider", address="100 Main St Suite A, Boston MA")
        G.add_node("NPI_67890", type="provider", address="100 Main St Suite A, Boston MA") # Address collision!
        G.add_node("Pat_Charlie", type="patient")
        G.add_node("NPI_99999", type="provider", address="200 Broadway St, Seattle WA")
        G.add_node("NPI_88888", type="provider", address="500 Elm St, Miami FL") # Geographic anomaly!
        
        # Add edges representing claims
        G.add_edge("Pat_Alice", "NPI_12345", transaction="claim", amount=500.0, date="2026-05-29")
        G.add_edge("Pat_Alice", "NPI_67890", transaction="claim", amount=1200.0, date="2026-05-29")
        G.add_edge("Pat_Bob", "NPI_12345", transaction="claim", amount=250.0, date="2026-05-28")
        G.add_edge("Pat_Charlie", "NPI_99999", transaction="claim", amount=450.0, date="2026-05-29")
        G.add_edge("Pat_Charlie", "NPI_88888", transaction="claim", amount=1500.0, date="2026-05-29") # Geographically distant on same day!
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
            
        return G
    except Exception as e:
        sys.stderr.write(f"Graph Construction Error: {str(e)}\n")
        return G

def check_collusion_network(patient_id: str, provider_npi: str, service_date: str) -> dict:
    """Analyze transaction graph topologies to identify address overlaps, geo-temporal leaps, and kickback rings."""
    try:
        G = build_relational_graph()
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
                edge_data = G.get_edge_data(patient_id, neighbor)
                if edge_data and edge_data.get("date") == service_date and neighbor != provider_npi:
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
                    state1 = prov1_addr.split(",")[-1].strip()[:2].upper() if "," in prov1_addr else ""
                    state2 = prov2_addr.split(",")[-1].strip()[:2].upper() if "," in prov2_addr else ""
                    
                    if state1 and state2 and state1 != state2:
                        flagged = True
                        findings.append(
                            f"Geo-Temporal Leap Impossibility: Patient '{patient_id}' has concurrent claims "
                            f"on {service_date} from provider {provider_npi} ({prov1_addr}) and provider {other_npi} "
                            f"({prov2_addr}). Geographically impossible same-day treatments."
                        )

        # Verification 3: Referral Ring Cycle Analysis
        # Check if the graph contains any directed cycles representing structured patient steering or referral loops
        cycles = list(nx.simple_cycles(G))
        for cycle in cycles:
            if provider_npi in cycle or patient_id in cycle:
                flagged = True
                findings.append(
                    f"Structured steering circle identified: Node belongs to a relational cycle "
                    f"({ ' -> '.join(cycle) }). Suspicion of systematic kickback/referral loop."
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
        sys.stderr.write(f"Error in collusion network check: {str(e)}\n")
        return {"flagged": False, "findings": [], "reason": f"Graph analysis error: {str(e)}"}
