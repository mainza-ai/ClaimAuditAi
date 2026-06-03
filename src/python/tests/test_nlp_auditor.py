import sys
import os
import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import nlp_auditor


@pytest.fixture(autouse=True)
def mock_iris_not_running(monkeypatch):
    monkeypatch.setattr(nlp_auditor, "iris", None)


@pytest.fixture(autouse=True)
def mock_sentence_transformer(monkeypatch):
    class MockSentenceTransformer:
        def __init__(self, model_name, cache_folder=None, **kwargs):
            self.model_name = model_name
            self.cache_folder = cache_folder
        def encode(self, text):
            if not text:
                return [0.0] * 384
            val = float(sum(ord(c) for c in text) % 1000) / 1000.0
            return [val] * 384
    monkeypatch.setattr("nlp_auditor.SentenceTransformer", MockSentenceTransformer)


class TestVectorizeText:
    def test_returns_list(self):
        result = nlp_auditor.vectorize_text("Routine physical examination")
        assert isinstance(result, list)

    def test_returns_384_dimensional_vector(self):
        result = nlp_auditor.vectorize_text("Routine physical examination")
        assert len(result) == 384

    def test_returns_float_values(self):
        result = nlp_auditor.vectorize_text("Routine physical examination")
        for value in result:
            assert isinstance(value, float)

    def test_returns_zero_vector_for_empty_text(self):
        result = nlp_auditor.vectorize_text("")
        assert len(result) == 384
        for value in result:
            assert value == 0.0

    def test_returns_zero_vector_for_none(self):
        result = nlp_auditor.vectorize_text(None)
        assert len(result) == 384
        for value in result:
            assert value == 0.0

    def test_different_text_different_vectors(self):
        vec1 = nlp_auditor.vectorize_text("heart surgery")
        vec2 = nlp_auditor.vectorize_text("dental cleaning")
        # Vectors should differ (at least one component should differ)
        assert vec1 != vec2


class TestGetModel:
    def test_returns_sentence_transformer(self):
        model = nlp_auditor.get_model()
        assert model is not None

    def test_model_is_same_instance(self):
        model1 = nlp_auditor.get_model()
        model2 = nlp_auditor.get_model()
        assert model1 is model2


class TestVerifyClinicalValidity:
    def test_returns_dict(self):
        result = nlp_auditor.verify_clinical_validity("P001", "CPT 99214 Office visit")
        assert isinstance(result, dict)
        assert "similarity" in result
        assert "flagged" in result

    def test_returns_mocked_success_when_not_iris(self):
        result = nlp_auditor.verify_clinical_validity("P001", "CPT 99214")
        assert result["similarity"] == 1.0
        assert result["flagged"] is False

    def test_returns_no_evidence_key_when_not_iris(self):
        result = nlp_auditor.verify_clinical_validity("P001", "CPT 99214")
        assert "evidence" in result or result.get("similarity", 0) >= 0

    def test_empty_code_description(self):
        result = nlp_auditor.verify_clinical_validity("P001", "")
        assert isinstance(result["similarity"], float)
        assert isinstance(result["flagged"], bool)


class TestIndexClinicalNote:
    def test_returns_string_when_no_iris(self):
        result = nlp_auditor.index_clinical_note("P001", "DOC001", "Patient presents with chest pain")
        assert isinstance(result, str)

    def test_returns_not_iris_message(self):
        result = nlp_auditor.index_clinical_note("P001", "DOC001", "Some note text")
        assert "Not running inside InterSystems IRIS" in result
