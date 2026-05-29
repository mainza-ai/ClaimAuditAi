# Autoencoder Not Detecting Anomalies

> Autoencoder not detecting anomalies occurs when bottleneck layer sigmoid functions saturate, causing the network to compress outlier values.

### Symptom
Anomalous claims return low reconstruction loss values (below the `0.47315` threshold) and bypass the payment integrity holds.

### Diagnostic Steps
1. **Check Output Layer Non-Linearities**: Inspect `autoencoder_train.py` to check if a sigmoid function is applied to the final decoder output layer.
2. **Print Reconstruction Loss Stats**: Run a manual evaluation script to print the raw reconstruction loss values for normal versus anomalous claims.

### Resolution
Modify the autoencoder decoder to use a linear output layer without sigmoid or ReLU saturation. This allows the output to scale linearly based on input Z-scores:
```python
# In autoencoder_train.py
self.decoder = nn.Sequential(
    nn.Linear(2, 8),
    nn.ReLU(),
    nn.Linear(8, 4) # Linear output layer (no sigmoid activation function)
)
```

## See Also
[[Troubleshooting Overview]] · [[Autoencoder Architecture]] · [[Reconstruction Loss Formula]]