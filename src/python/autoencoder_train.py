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
        def __init__(self, input_dim=8):
            super(ClaimAutoencoder, self).__init__()
            # Encoder bottleneck compression
            self.encoder = nn.Sequential(
                nn.Linear(input_dim, 24),
                nn.ReLU(),
                nn.Linear(24, 12),
                nn.ReLU(),
                nn.Linear(12, 6), # Latent bottleneck
                nn.ReLU()
            )
            # Decoder reconstruction
            self.decoder = nn.Sequential(
                nn.Linear(6, 12),
                nn.ReLU(),
                nn.Linear(12, 24),
                nn.ReLU(),
                nn.Linear(24, input_dim) # Linear activation for real-valued reconstruction
            )

        def forward(self, x):
            x = self.encoder(x)
            x = self.decoder(x)
            return x
else:
    class ClaimAutoencoder:
        pass

def normalize_features(features, mean, std):
    """Normalize continuous features using Z-score. Categorical features use fixed scaling."""
    epsilon = 1e-8
    normalized = np.copy(features)
    num_features = features.shape[1]
    
    # Scale continuous variables
    continuous_indices = [0, 1, 3, 4]
    if num_features >= 8:
        continuous_indices.append(7)
        
    for i in continuous_indices:
        if i < num_features and i < len(mean) and i < len(std):
            normalized[:, i] = (features[:, i] - mean[i]) / (std[i] + epsilon)
            
    # SpecialtyCode is categorical — scale to stable [0, 1] range
    if num_features > 2:
        normalized[:, 2] = features[:, 2] / 100.0
        
    # code_count — scale by typical max of 10
    if num_features > 5:
        normalized[:, 5] = features[:, 5] / 10.0
        
    # service_month — already 1-12, scale to [0, 1]
    if num_features > 6:
        normalized[:, 6] = features[:, 6] / 12.0
        
    return normalized

def train_autoencoder() -> str:
    """Load historical ExplanationOfBenefit projected claims and train the Autoencoder model natively."""
    if not torch:
        return "PyTorch is not installed in the environment."
        
    try:
        # Load data from dynamic SQL if running in IRIS
        historical_claims = []
        if iris:
            stmt = iris.sql.prepare(
                "SELECT CP.BilledAmount, CP.ItemCount, CP.SpecialtyCode, CP.PatientAge, CP.DurationDays, "
                "CP.ItemCount AS CodeCount, "
                "CAST(SUBSTRING(CP.ServiceDate, 6, 2) AS INTEGER) AS ServiceMonth, "
                "(SELECT COUNT(*) FROM ClaimAudit.ClaimProjections CP2 WHERE CP2.ProviderNPI = CP.ProviderNPI) AS ProviderBusyness "
                "FROM ClaimAudit.ClaimProjections CP"
            )
            rs = stmt.execute()
            for row in rs:
                r_billed = float(row[0])
                r_items = float(row[1])
                r_specialty = float(row[2])
                r_age = float(row[3])
                r_duration = float(row[4])
                
                try:
                    r_code_count = float(row[5])
                except Exception:
                    r_code_count = r_items
                    
                try:
                    r_service_month = float(max(1, min(12, int(row[6]) if row[6] else 6)))
                except Exception:
                    r_service_month = 6.0
                    
                try:
                    r_provider_busyness = float(row[7])
                except Exception:
                    r_provider_busyness = 1.0
                    
                historical_claims.append([
                    r_billed,
                    r_items,
                    r_specialty,
                    r_age,
                    r_duration,
                    r_code_count,
                    r_service_month,
                    r_provider_busyness,
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
        
        # Normalize dataset
        normalized_data = normalize_features(data, means, stds)
        tensor_data = torch.tensor(normalized_data, dtype=torch.float32)
        
        # Set random seeds for reproducibility and deterministic training
        np.random.seed(42)
        torch.manual_seed(42)
        
        # Validation Split: 15% split if we have enough samples
        n_samples = len(historical_claims)
        if n_samples >= 10:
            indices = np.arange(n_samples)
            np.random.shuffle(indices)
            val_size = max(1, int(n_samples * 0.15))
            val_indices = indices[:val_size]
            train_indices = indices[val_size:]
            
            train_data = tensor_data[train_indices]
            val_data = tensor_data[val_indices]
        else:
            train_data = tensor_data
            val_data = tensor_data

        # Check if old model exists to compute baseline validation loss
        old_loss = None
        if os.path.exists(MODEL_PATH) and os.path.exists(STATS_PATH):
            try:
                old_model = ClaimAutoencoder(input_dim=5)
                old_model.load_state_dict(torch.load(MODEL_PATH, weights_only=True))
                old_model.eval()
                with torch.no_grad():
                    old_reconstructed = old_model(val_data)
                    old_loss = float(torch.mean((old_reconstructed - val_data) ** 2).item())
            except Exception:
                pass
        
        # Model & Training Staging
        torch.manual_seed(42)
        model = ClaimAutoencoder(input_dim=8)
        criterion = nn.MSELoss()
        optimizer = optim.Adam(model.parameters(), lr=0.01)
        
        # In-memory training loop
        epochs = 150
        model.train()
        for epoch in range(epochs):
            optimizer.zero_grad()
            outputs = model(train_data)
            loss = criterion(outputs, train_data)
            loss.backward()
            optimizer.step()
            
        # Evaluate candidate model on validation data
        model.eval()
        with torch.no_grad():
            candidate_reconstructed = model(val_data)
            candidate_loss = float(torch.mean((candidate_reconstructed - val_data) ** 2).item())

        # Validate drift against old loss (15% limit)
        if old_loss is not None and old_loss > 1e-6:
            drift_percent = (candidate_loss - old_loss) / old_loss
            if drift_percent > 0.15:
                # Log critical warning to stderr and reject the candidate update
                sys.stderr.write(f"Autoencoder validation failure: drift of {drift_percent*100:.2f}% exceeds the 15% limit. Candidate Loss: {candidate_loss:.6f}, Old Loss: {old_loss:.6f}\n")
                return f"Error: Validation drift of {drift_percent*100:.2f}% exceeds 15% limit. Training rejected to prevent model degradation."

        # Calculate dynamic reconstruction threshold (95th percentile of normal reconstruction loss)
        with torch.no_grad():
            reconstructed = model(tensor_data)
            mse_losses = torch.mean((reconstructed - tensor_data) ** 2, dim=1).numpy()
            threshold = max(np.percentile(mse_losses, 95), 0.02)
            
        # Safeguard: Rotate backups of previous successful models (up to 3 versions)
        for i in range(2, 0, -1):
            old_model_file = MODEL_PATH.replace(".pth", f"_v{i}.pth")
            old_stats_file = STATS_PATH.replace(".npz", f"_v{i}.npz")
            next_model_file = MODEL_PATH.replace(".pth", f"_v{i+1}.pth")
            next_stats_file = STATS_PATH.replace(".npz", f"_v{i+1}.npz")
            if os.path.exists(old_model_file):
                try:
                    if os.path.exists(next_model_file):
                        os.remove(next_model_file)
                    os.rename(old_model_file, next_model_file)
                except Exception:
                    pass
            if os.path.exists(old_stats_file):
                try:
                    if os.path.exists(next_stats_file):
                        os.remove(next_stats_file)
                    os.rename(old_stats_file, next_stats_file)
                except Exception:
                    pass
                
        # Move current successful model to v1
        if os.path.exists(MODEL_PATH):
            try:
                backup_m = MODEL_PATH.replace(".pth", "_v1.pth")
                if os.path.exists(backup_m):
                    os.remove(backup_m)
                os.rename(MODEL_PATH, backup_m)
            except Exception:
                pass
        if os.path.exists(STATS_PATH):
            try:
                backup_s = STATS_PATH.replace(".npz", "_v1.npz")
                if os.path.exists(backup_s):
                    os.remove(backup_s)
                os.rename(STATS_PATH, backup_s)
            except Exception:
                pass

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
        # Minimum absolute threshold floor — even with homogeneous training data,
        # the model must maintain a floor so outliers are detectable. Without this,
        # training on identical features produces a threshold near zero, hiding all anomalies.
        percentile_threshold = float(stats["threshold"]) if "threshold" in stats else 0.02
        threshold = max(percentile_threshold, 0.02)

        model = ClaimAutoencoder(input_dim=8)
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

def evaluate_claim_anomaly(billed_amount: float, item_count: float, specialty_code: float, patient_age: float, duration_days: float, code_count: float = 1.0, service_month: float = 6.0, provider_busyness: float = 1.0) -> dict:
    """Score incoming intercepted claims and calculate PyTorch reconstruction error."""
    if not torch:
        return {"loss": 0.0, "threshold": 0.1, "flagged": False, "reason": "PyTorch not available."}

    try:
        # Train model if it doesn't exist
        if not os.path.exists(MODEL_PATH) or not os.path.exists(STATS_PATH):
            result = train_autoencoder()
            _invalidate_cache()
            # If training was skipped due to insufficient data, return not-flagged (not enough data to judge)
            if isinstance(result, dict) and result.get("status") == "skipped":
                return {"loss": 0.0, "threshold": 0.02, "flagged": False, "reason": f"Tier 2 autoencoder: {result['message']}"}

        cache = _get_cached_model()
        if cache is None:
            result = train_autoencoder()
            if isinstance(result, dict) and result.get("status") == "skipped":
                return {"loss": 0.0, "threshold": 0.02, "flagged": False, "reason": f"Tier 2 autoencoder: {result['message']}"}
            cache = _get_cached_model()
        if cache is None:
            return {"loss": 0.0, "threshold": 0.1, "flagged": True, "reason": "Tier 2 autoencoder: model training failed. Manual review required."}

        model = cache["model"]
        means = cache["means"]
        stds = cache["stds"]
        threshold = cache["threshold"]

        claim_features = np.array([[billed_amount, item_count, specialty_code, patient_age, duration_days, code_count, service_month, provider_busyness]], dtype=np.float32)
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
