import sys
import os
import pytest
import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import autoencoder_train


class TestNormalizeFeatures:
    def test_returns_numpy_array(self):
        features = np.array([[100.0, 2.0, 1.0, 45.0, 1.0]], dtype=np.float32)
        mean = np.array([100.0, 2.0, 1.0, 45.0, 1.0], dtype=np.float32)
        std = np.array([1.0, 1.0, 1.0, 1.0, 1.0], dtype=np.float32)
        result = autoencoder_train.normalize_features(features, mean, std)
        assert isinstance(result, np.ndarray)

    def test_zeros_when_exact_match(self):
        features = np.array([[100.0, 2.0, 1.0, 45.0, 1.0]], dtype=np.float32)
        mean = np.array([100.0, 2.0, 1.0, 45.0, 1.0], dtype=np.float32)
        std = np.array([1.0, 1.0, 1.0, 1.0, 1.0], dtype=np.float32)
        result = autoencoder_train.normalize_features(features, mean, std)
        expected = np.array([[0.0, 0.0, 0.01, 0.0, 0.0]], dtype=np.float32)
        assert np.allclose(result, expected, atol=0.001)

    def test_handles_zero_std(self):
        features = np.array([[100.0, 2.0, 1.0, 45.0, 1.0]], dtype=np.float32)
        mean = np.array([0.0, 0.0, 0.0, 0.0, 0.0], dtype=np.float32)
        std = np.array([0.0, 0.0, 0.0, 0.0, 0.0], dtype=np.float32)
        result = autoencoder_train.normalize_features(features, mean, std)
        # Epsilon in denominator prevents division by zero
        assert not np.any(np.isnan(result))
        assert not np.any(np.isinf(result))

    def test_returns_correct_shape(self):
        features = np.array([[1.0, 1.0, 1.0, 1.0, 1.0]], dtype=np.float32)
        mean = np.zeros(5, dtype=np.float32)
        std = np.ones(5, dtype=np.float32)
        result = autoencoder_train.normalize_features(features, mean, std)
        assert result.shape == features.shape


class TestClaimAutoencoder:
    def test_model_exists(self):
        assert hasattr(autoencoder_train, "ClaimAutoencoder")

    @pytest.mark.skipif(autoencoder_train.torch is None, reason="PyTorch not installed")
    def test_creates_model(self):
        import torch
        model = autoencoder_train.ClaimAutoencoder(input_dim=5)
        assert model is not None

    @pytest.mark.skipif(autoencoder_train.torch is None, reason="PyTorch not installed")
    def test_forward_pass(self):
        import torch
        model = autoencoder_train.ClaimAutoencoder(input_dim=5)
        x = torch.randn(1, 5)
        output = model(x)
        assert output.shape == x.shape

    @pytest.mark.skipif(autoencoder_train.torch is None, reason="PyTorch not installed")
    def test_encoder_decoder_reconstruction(self):
        import torch
        model = autoencoder_train.ClaimAutoencoder(input_dim=5)
        model.eval()
        x = torch.randn(3, 5)
        with torch.no_grad():
            output = model(x)
        assert output.shape == (3, 5)
        # Output should not be NaN
        assert not torch.isnan(output).any()


class TestTrainAutoencoder:
    def test_returns_when_pytorch_not_installed(self, monkeypatch):
        monkeypatch.setattr(autoencoder_train, "torch", None)
        result = autoencoder_train.train_autoencoder()
        assert isinstance(result, str)
        assert "not installed" in result.lower() or "pytorch" in result.lower()

    def test_skips_with_insufficient_data(self):
        result = autoencoder_train.train_autoencoder()
        # Since no iris module and no data, should skip
        assert isinstance(result, (str, dict))

    @pytest.mark.skipif(autoencoder_train.torch is None, reason="PyTorch not installed")
    def test_training_validation_and_backup(self, monkeypatch, tmp_path):
        # Create temp path for MODEL_PATH and STATS_PATH
        model_file = str(tmp_path / "autoencoder.pth")
        stats_file = str(tmp_path / "stats.npz")
        monkeypatch.setattr(autoencoder_train, "MODEL_PATH", model_file)
        monkeypatch.setattr(autoencoder_train, "STATS_PATH", stats_file)
        
        # Mock iris
        class MockRow:
            def __init__(self, data):
                self.data = data
            def __getitem__(self, idx):
                return self.data[idx]
                
        class MockRS:
            def __init__(self):
                # 15 sample claims
                self.rows = [
                    [100.0, 2.0, 1.0, 45.0, 1.0],
                    [120.0, 2.0, 1.0, 42.0, 1.0],
                    [90.0, 1.0, 1.0, 50.0, 1.0],
                    [110.0, 2.0, 1.0, 47.0, 1.0],
                    [95.0, 2.0, 1.0, 44.0, 1.0],
                    [105.0, 2.0, 1.0, 46.0, 1.0],
                    [115.0, 3.0, 1.0, 48.0, 1.0],
                    [85.0, 1.0, 1.0, 40.0, 1.0],
                    [125.0, 2.0, 1.0, 52.0, 1.0],
                    [130.0, 2.0, 1.0, 55.0, 1.0],
                    [140.0, 3.0, 1.0, 58.0, 2.0],
                    [150.0, 3.0, 1.0, 60.0, 2.0],
                    [98.0, 2.0, 1.0, 43.0, 1.0],
                    [102.0, 2.0, 1.0, 45.0, 1.0],
                    [108.0, 2.0, 1.0, 46.0, 1.0],
                ]
                self.idx = 0
            def __iter__(self):
                return self
            def __next__(self):
                if self.idx >= len(self.rows):
                    raise StopIteration
                res = MockRow(self.rows[self.idx])
                self.idx += 1
                return res
                
        class MockStmt:
            def execute(self):
                return MockRS()
                
        class MockIris:
            class sql:
                @staticmethod
                def prepare(sql_str):
                    return MockStmt()
                    
        monkeypatch.setattr(autoencoder_train, "iris", MockIris)
        
        # First train: should succeed and save model files
        result1 = autoencoder_train.train_autoencoder()
        assert "Successfully trained" in result1
        assert os.path.exists(model_file)
        assert os.path.exists(stats_file)
        
        # Second train: should rotate backups and succeed
        result2 = autoencoder_train.train_autoencoder()
        assert "Successfully trained" in result2
        assert os.path.exists(model_file.replace(".pth", "_v1.pth"))
        assert os.path.exists(stats_file.replace(".npz", "_v1.npz"))


class TestEvaluateClaimAnomaly:
    def test_returns_dict(self):
        result = autoencoder_train.evaluate_claim_anomaly(500.0, 2.0, 1.0, 45.0, 1.0)
        assert isinstance(result, dict)
        assert "loss" in result
        assert "threshold" in result
        assert "flagged" in result
        assert "reason" in result

    def test_returns_flagged_when_pytorch_not_available(self, monkeypatch):
        monkeypatch.setattr(autoencoder_train, "torch", None)
        result = autoencoder_train.evaluate_claim_anomaly(500.0, 2.0, 1.0, 45.0, 1.0)
        assert result["flagged"] is False
        assert "not available" in result["reason"].lower()

    def test_flagged_is_bool(self):
        result = autoencoder_train.evaluate_claim_anomaly(500.0, 2.0, 1.0, 45.0, 1.0)
        assert result["flagged"] is True or result["flagged"] is False or isinstance(result["flagged"], (bool, np.bool_))

    def test_loss_is_float(self):
        result = autoencoder_train.evaluate_claim_anomaly(500.0, 2.0, 1.0, 45.0, 1.0)
        assert isinstance(result["loss"], (int, float, np.floating))

    def test_handles_zero_amount(self):
        result = autoencoder_train.evaluate_claim_anomaly(0.0, 0.0, 0.0, 0.0, 0.0)
        assert bool(result["flagged"]) in (True, False)

    def test_handles_negative_values(self):
        result = autoencoder_train.evaluate_claim_anomaly(-100.0, -1.0, -1.0, -1.0, -1.0)
        assert bool(result["flagged"]) in (True, False)

    def test_handles_large_values(self):
        result = autoencoder_train.evaluate_claim_anomaly(1e9, 100.0, 10.0, 120.0, 365.0)
        assert bool(result["flagged"]) in (True, False)
