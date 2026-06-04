import sys
import os
import json
import pytest
import networkx as nx
from unittest.mock import patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import graph_analyzer


@pytest.fixture(autouse=True)
def mock_iris_not_running(monkeypatch):
    monkeypatch.setattr(graph_analyzer, "iris", None)


def _make_test_graph() -> nx.MultiDiGraph:
    """Build a deterministic test graph for collusion analysis."""
    G = nx.MultiDiGraph()
    G.add_node("Pat_A", type="patient")
    G.add_node("Pat_B", type="patient")
    G.add_node("Pat_C", type="patient")
    G.add_node("NPI_A", type="provider", address="100 Main St Suite A, Boston MA")
    G.add_node("NPI_B", type="provider", address="100 Main St Suite A, Boston MA")  # address collision with NPI_A
    G.add_node("NPI_C", type="provider", address="200 Broadway St, Seattle WA")
    G.add_node("NPI_D", type="provider", address="500 Elm St, Miami FL")

    G.add_edge("Pat_A", "NPI_A", transaction="claim", amount=500.0, date="2026-05-29")
    G.add_edge("Pat_A", "NPI_B", transaction="claim", amount=1200.0, date="2026-05-29")
    G.add_edge("Pat_B", "NPI_A", transaction="claim", amount=250.0, date="2026-05-28")
    G.add_edge("Pat_C", "NPI_C", transaction="claim", amount=450.0, date="2026-05-29")
    G.add_edge("Pat_A", "NPI_D", transaction="claim", amount=1500.0, date="2026-05-29")  # geo-temporal: MA vs FL same day
    return G


class TestBuildRelationalGraph:
    def test_returns_multidigraph(self):
        G = graph_analyzer.build_relational_graph()
        assert isinstance(G, nx.MultiDiGraph)

    def test_returns_empty_when_no_iris(self):
        G = graph_analyzer.build_relational_graph()
        assert G.number_of_nodes() == 0
        assert G.number_of_edges() == 0


class TestCheckCollusionNetwork:
    def test_returns_dict(self):
        G = _make_test_graph()
        with patch("graph_analyzer._get_cached_graph", return_value=G):
            result = graph_analyzer.check_collusion_network("Pat_A", "NPI_A", "2026-05-29")
            assert isinstance(result, dict)
            assert "flagged" in result
            assert "findings" in result
            assert "reason" in result

    def test_flagged_is_bool(self):
        G = _make_test_graph()
        with patch("graph_analyzer._get_cached_graph", return_value=G):
            result = graph_analyzer.check_collusion_network("Pat_A", "NPI_A", "2026-05-29")
            assert isinstance(result["flagged"], bool)

    def test_detects_address_collision(self):
        G = _make_test_graph()
        with patch("graph_analyzer._get_cached_graph", return_value=G):
            result = graph_analyzer.check_collusion_network("Pat_A", "NPI_A", "2026-05-29")
            assert result["flagged"] is True
            assert any("Address Collision" in f for f in result["findings"])

    def test_findings_is_list(self):
        G = _make_test_graph()
        with patch("graph_analyzer._get_cached_graph", return_value=G):
            result = graph_analyzer.check_collusion_network("Pat_A", "NPI_A", "2026-05-29")
            assert isinstance(result["findings"], list)

    def test_graceful_on_nonexistent_nodes(self):
        G = _make_test_graph()
        with patch("graph_analyzer._get_cached_graph", return_value=G):
            result = graph_analyzer.check_collusion_network("nonexistent", "nonexistent", "2026-01-01")
            assert isinstance(result["flagged"], bool)
            assert result["reason"] == ""

    def test_detects_geo_temporal_leap(self):
        G = _make_test_graph()
        with patch("graph_analyzer._get_cached_graph", return_value=G):
            result = graph_analyzer.check_collusion_network("Pat_A", "NPI_D", "2026-05-29")
            assert result["flagged"] is True
            assert any("Geo-Temporal Leap" in f for f in result["findings"])

    def test_detects_undirected_cycle(self):
        G = nx.MultiDiGraph()
        G.add_node("Pat_A", type="patient")
        G.add_node("Pat_B", type="patient")
        G.add_node("NPI_A", type="provider", address="100 Main St")
        G.add_node("NPI_B", type="provider", address="200 Main St")

        G.add_edge("Pat_A", "NPI_A", transaction="claim", amount=100.0, date="2026-05-29")
        G.add_edge("Pat_B", "NPI_A", transaction="claim", amount=100.0, date="2026-05-29")
        G.add_edge("Pat_B", "NPI_B", transaction="claim", amount=100.0, date="2026-05-29")
        G.add_edge("Pat_A", "NPI_B", transaction="claim", amount=100.0, date="2026-05-29")

        with patch("graph_analyzer._get_cached_graph", return_value=G):
            result = graph_analyzer.check_collusion_network("Pat_A", "NPI_A", "2026-05-29")
            assert result["flagged"] is True
            assert any("collusion loop" in f.lower() for f in result["findings"])


class TestExportGraphForUI:
    def test_returns_json_string(self):
        G = _make_test_graph()
        with patch("graph_analyzer._get_cached_graph", return_value=G):
            result = graph_analyzer.export_graph_for_ui()
            assert isinstance(result, str)

    def test_json_has_required_keys(self):
        G = _make_test_graph()
        with patch("graph_analyzer._get_cached_graph", return_value=G):
            result = json.loads(graph_analyzer.export_graph_for_ui())
            assert "nodes" in result
            assert "edges" in result
            assert "insights" in result
            assert "nodeCount" in result
            assert "edgeCount" in result
            assert "insightCount" in result

    def test_node_count_matches_data(self):
        G = _make_test_graph()
        with patch("graph_analyzer._get_cached_graph", return_value=G):
            result = json.loads(graph_analyzer.export_graph_for_ui())
            assert result["nodeCount"] == len(result["nodes"])

    def test_edge_count_matches_data(self):
        G = _make_test_graph()
        with patch("graph_analyzer._get_cached_graph", return_value=G):
            result = json.loads(graph_analyzer.export_graph_for_ui())
            assert result["edgeCount"] == len(result["edges"])

    def test_nodes_have_data_with_id_label_type(self):
        G = _make_test_graph()
        with patch("graph_analyzer._get_cached_graph", return_value=G):
            result = json.loads(graph_analyzer.export_graph_for_ui())
            for node in result["nodes"]:
                assert "data" in node
                assert "id" in node["data"]
                assert "label" in node["data"]
                assert "type" in node["data"]

    def test_edges_have_data_with_id_source_target(self):
        G = _make_test_graph()
        with patch("graph_analyzer._get_cached_graph", return_value=G):
            result = json.loads(graph_analyzer.export_graph_for_ui())
            for edge in result["edges"]:
                assert "data" in edge
                assert "id" in edge["data"]
                assert "source" in edge["data"]
                assert "target" in edge["data"]

    def test_detects_address_collision_insights(self):
        G = _make_test_graph()
        with patch("graph_analyzer._get_cached_graph", return_value=G):
            result = json.loads(graph_analyzer.export_graph_for_ui())
            insight_types = [i["type"] for i in result["insights"]]
            assert "address_collision" in insight_types

    def test_detects_geo_temporal_leap_insights(self):
        G = _make_test_graph()
        with patch("graph_analyzer._get_cached_graph", return_value=G):
            result = json.loads(graph_analyzer.export_graph_for_ui())
            insight_types = [i["type"] for i in result["insights"]]
            assert "geo_temporal_leap" in insight_types
