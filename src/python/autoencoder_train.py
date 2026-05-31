import os
import sys
import numpy as np
import threading

# Standard PyTorch imports
try:
    import torch
    import torch.nn as nn
    import torch.optim as optim
except ImportError:
    torch = None
    nn = None
    optim = None

try:
    import iris
except ImportError:
    iris = None

# Model File Path
MODEL_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "autoencoder.pth")
STATS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "stats.npz")

# Module-level cache to avoid loading model from disk on every claim evaluation
_evaluation_cache = {}
_evaluation_lock = threading.Lock()

# Network definition in PyTorch
if torch:
    class ClaimAutoencoder(nn.Module):
        def __init__(self, input_dim=5):
            super(ClaimAutoencoder, self).__init__()
            # Encoder bottleneck compression
            self.encoder = nn.Sequential(
                nn.Linear(input_dim, 16),
                nn.ReLU(),
                nn.Linear(16, 8),
                nn.ReLU(),
                nn.Linear(8, 4), # Latent bottleneck
                nn.ReLU()
            )
            # Decoder reconstruction
            self.decoder = nn.Sequential(
                nn.Linear(4, 8),
                nn.ReLU(),
                nn.Linear(8, 16),
                nn.ReLU(),
                nn.Linear(16, input_dim) # Linear activation for real-valued reconstruction
            )

        def forward(self, x):
            x = self.encoder(x)
            x = self.decoder(x)
            return x
else:
    class ClaimAutoencoder:
        pass

def normalize_features(features, mean, std):
    """Normalize using standard Z-score scaling."""
    epsilon = 1e-8
    return (features - mean) / (std + epsilon)

def train_autoencoder() -> str:
    """Load historical ExplanationOfBenefit projected claims and train the Autoencoder model natively."""
    if not torch:
        return "PyTorch is not installed in the environment."
        
    try:
        # Load data from dynamic SQL if running in IRIS
        historical_claims = []
        if iris:
            stmt = iris.sql.prepare(
                "SELECT BilledAmount, ItemCount, SpecialtyCode, PatientAge, DurationDays "
                "FROM ClaimAudit.ClaimProjections"
            )
            rs = stmt.execute()
            for row in rs:
                historical_claims.append([
                    float(row[0]), # BilledAmount
                    float(row[1]), # ItemCount
                    float(row[2]), # SpecialtyCode
                    float(row[3]), # PatientAge
                    float(row[4])  # DurationDays
                ])
        
        # Require a minimum of 5 real claims to train a meaningful model.
        # Synthetic noise-based training produces an arbitrary threshold that
        # cannot distinguish genuine anomalies.
        if len(historical_claims) < 5:
            return {"status": "skipped", "message": f"Insufficient training data ({len(historical_claims)} < 5)."}

        data = np.array(historical_claims, dtype=np.float32)
        
        # Feature Statistics for normalization
        means = np.mean(data, axis=0)
        stds = np.std(data, axis=0)
        np.savez(STATS_PATH, means=means, stds=stds)
        
        # Normalize dataset
        normalized_data = normalize_features(data, means, stds)
        tensor_data = torch.tensor(normalized_data, dtype=torch.float32)
        
        # Model & Training Staging
        model = ClaimAutoencoder(input_dim=5)
        criterion = nn.MSELoss()
        optimizer = optim.Adam(model.parameters(), lr=0.01)
        
        # In-memory training loop
        epochs = 150
        model.train()
        for epoch in range(epochs):
            optimizer.zero_grad()
            outputs = model(tensor_data)
            loss = criterion(outputs, tensor_data)
            loss.backward()
            optimizer.step()
            
        # Calculate dynamic reconstruction threshold (95th percentile of normal reconstruction loss)
        model.eval()
        with torch.no_grad():
            reconstructed = model(tensor_data)
            mse_losses = torch.mean((reconstructed - tensor_data) ** 2, dim=1).numpy()
            threshold = np.percentile(mse_losses, 95)
            
        # Save model state and parameters
        torch.save(model.state_dict(), MODEL_PATH)
        np.savez(STATS_PATH, means=means, stds=stds, threshold=threshold)
        _invalidate_cache()

        return f"Successfully trained Autoencoder. Normal threshold: {threshold:.6f}"
        
    except Exception as e:
        sys.stderr.write(f"Autoencoder Training Error: {str(e)}\n")
        return f"Error: {str(e)}"

def _get_cached_model():
    """Load model and statistics from disk once, cache at module level. Thread-safe."""
    if torch is None:
        return None

    with _evaluation_lock:
        if "model" in _evaluation_cache:
            return _evaluation_cache

        if not os.path.exists(MODEL_PATH) or not os.path.exists(STATS_PATH):
            return None

        stats = np.load(STATS_PATH)
        means = stats["means"]
        stds = stats["stds"]
        threshold = float(stats["threshold"]) if "threshold" in stats else 0.02

        model = ClaimAutoencoder(input_dim=5)
        model.load_state_dict(torch.load(MODEL_PATH, weights_only=True))
        model.eval()

        _evaluation_cache["model"] = model
        _evaluation_cache["means"] = means
        _evaluation_cache["stds"] = stds
        _evaluation_cache["threshold"] = threshold

        return _evaluation_cache

def _invalidate_cache():
    """Clear cached model after training so next evaluation picks up new model."""
    with _evaluation_lock:
        _evaluation_cache.clear()

def evaluate_claim_anomaly(billed_amount: float, item_count: float, specialty_code: float, patient_age: float, duration_days: float) -> dict:
    """Score incoming intercepted claims and calculate PyTorch reconstruction error."""
    if not torch:
        return {"loss": 0.0, "threshold": 0.1, "flagged": False, "reason": "PyTorch not available."}

    try:
        # Train model if it doesn't exist
        if not os.path.exists(MODEL_PATH) or not os.path.exists(STATS_PATH):
            train_autoencoder()
            _invalidate_cache()

        cache = _get_cached_model()
        if cache is None:
            train_autoencoder()
            cache = _get_cached_model()
        if cache is None:
            return {"loss": 0.0, "threshold": 0.1, "flagged": True, "reason": "Tier 2 autoencoder: model training failed. Manual review required."}

        model = cache["model"]
        means = cache["means"]
        stds = cache["stds"]
        threshold = cache["threshold"]

        claim_features = np.array([[billed_amount, item_count, specialty_code, patient_age, duration_days]], dtype=np.float32)
        normalized = normalize_features(claim_features, means, stds)
        tensor_claim = torch.tensor(normalized, dtype=torch.float32)

        with torch.no_grad():
            reconstructed = model(tensor_claim)
            loss_tensor = torch.mean((reconstructed - tensor_claim) ** 2, dim=1)
            loss = float(loss_tensor.item())

        flagged = loss > threshold
        reason = ""
        if flagged:
            reason = (
                f"Statistical anomaly flagged. Claim features represent an unusual billing structure "
                f"outlier. Reconstruction Loss: {loss:.5f} (Threshold: {threshold:.5f})"
            )

        return {
            "loss": loss,
            "threshold": float(threshold),
            "flagged": flagged,
            "reason": reason
        }

    except Exception as e:
        sys.stderr.write(f"Error in evaluate_claim_anomaly: {str(e)}\n")
        return {
            "loss": 0.0,
            "threshold": 0.1,
            "flagged": True,
            "reason": f"Tier 2 autoencoder evaluation error: {str(e)}. Claim requires manual adjudication review."
        }
