import sys
import os
import pytest
import networkx as nx

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import graph_analyzer


@pytest.fixture(autouse=True)
def mock_iris_not_running(monkeypatch):
    monkeypatch.setattr(graph_analyzer, "iris", None)


class TestBuildRelationalGraph:
    def test_returns_digraph(self):
        G = graph_analyzer.build_relational_graph()
        assert isinstance(G, nx.DiGraph)

    def test_has_mock_nodes_when_no_iris(self):
        G = graph_analyzer.build_relational_graph()
        assert G.number_of_nodes() > 0
        assert G.has_node("Pat_Alice")
        assert G.has_node("NPI_12345")

    def test_nodes_have_type_attribute(self):
        G = graph_analyzer.build_relational_graph()
        assert G.nodes["Pat_Alice"]["type"] == "patient"
        assert G.nodes["NPI_12345"]["type"] == "provider"

    def test_providers_have_address_attribute(self):
        G = graph_analyzer.build_relational_graph()
        assert "address" in G.nodes["NPI_12345"]
        assert len(G.nodes["NPI_12345"]["address"]) > 0

    def test_edges_have_transaction_data(self):
        G = graph_analyzer.build_relational_graph()
        edges = list(G.edges(data=True))
        assert len(edges) > 0
        for edge in edges:
            # MultiDiGraph returns (src, dst, key, data)
            data = edge[3] if len(edge) >= 4 else edge[2]
            assert "transaction" in data

    def test_edge_transaction_is_claim(self):
        G = graph_analyzer.build_relational_graph()
        for edge in G.edges(data=True):
            data = edge[3] if len(edge) >= 4 else edge[2]
            assert data["transaction"] == "claim"


class TestCheckCollusionNetwork:
    def test_returns_dict(self):
        result = graph_analyzer.check_collusion_network("Pat_Alice", "NPI_12345", "2026-05-29")
        assert isinstance(result, dict)
        assert "flagged" in result
        assert "findings" in result
        assert "reason" in result

    def test_flagged_is_bool(self):
        result = graph_analyzer.check_collusion_network("Pat_Alice", "NPI_12345", "2026-05-29")
        assert isinstance(result["flagged"], bool)

    def test_detects_address_collision(self):
        # NPI_12345 and NPI_67890 share the same address in mock data
        result = graph_analyzer.check_collusion_network("Pat_Alice", "NPI_12345", "2026-05-29")
        # The result should be flagged due to address collision
        assert result["flagged"] is True

    def test_different_providers_different_days_not_flagged(self):
        result = graph_analyzer.check_collusion_network("Pat_Bob", "NPI_12345", "2026-05-27")
        assert isinstance(result["flagged"], bool)

    def test_findings_is_list(self):
        result = graph_analyzer.check_collusion_network("Pat_Alice", "NPI_12345", "2026-05-29")
        assert isinstance(result["findings"], list)

    def test_graceful_on_nonexistent_nodes(self):
        result = graph_analyzer.check_collusion_network("nonexistent_pat", "nonexistent_npi", "2026-01-01")
        assert isinstance(result["flagged"], bool)
        assert result["reason"] == ""


class TestExportGraphForUI:
    def test_returns_json_string(self):
        result = graph_analyzer.export_graph_for_ui()
        assert isinstance(result, str)

    def test_json_has_required_keys(self):
        import json
        result = json.loads(graph_analyzer.export_graph_for_ui())
        assert "nodes" in result
        assert "edges" in result
        assert "insights" in result
        assert "nodeCount" in result
        assert "edgeCount" in result
        assert "insightCount" in result

    def test_node_count_matches_data(self):
        import json
        result = json.loads(graph_analyzer.export_graph_for_ui())
        assert result["nodeCount"] == len(result["nodes"])

    def test_edge_count_matches_data(self):
        import json
        result = json.loads(graph_analyzer.export_graph_for_ui())
        assert result["edgeCount"] == len(result["edges"])

    def test_nodes_have_data_with_id_label_type(self):
        import json
        result = json.loads(graph_analyzer.export_graph_for_ui())
        for node in result["nodes"]:
            assert "data" in node
            assert "id" in node["data"]
            assert "label" in node["data"]
            assert "type" in node["data"]

    def test_edges_have_data_with_id_source_target(self):
        import json
        result = json.loads(graph_analyzer.export_graph_for_ui())
        for edge in result["edges"]:
            assert "data" in edge
            assert "id" in edge["data"]
            assert "source" in edge["data"]
            assert "target" in edge["data"]

    def test_detects_address_collision_insights(self):
        import json
        result = json.loads(graph_analyzer.export_graph_for_ui())
        insight_types = [i["type"] for i in result["insights"]]
        assert "address_collision" in insight_types
