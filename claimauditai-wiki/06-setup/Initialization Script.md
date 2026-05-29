# Initialization Script

> The initialization script automates namespace creation, package compilation, database indexing, and machine learning model pre-training.

The build process is automated using the [iris.script](file:///Users/mck/Desktop/claimauditai/iris.script) manifest, which executes the following setup steps:

```
[iris.script] ──> Create INTEROP Namespace ──> Load ZPM Classes ──> Run Engine.Setup()
                                                                         |
                                                                         v
HNSW Index Built <── Autoencoder Pre-Trained <── Create SQL Tables <-----+
```

1. **Namespace Provisioning**: Creates the `INTEROP` database namespace and sets up interoperability parameters.
2. **Package Loading**: Loads and compiles ZPM class files under `/home/irisowner/dev/src/cls`.
3. **Database Configuration**: Triggers `##class(ClaimAudit.AI.Engine).Setup()`, which creates the dynamic SQL projection tables and builds the native HNSW vector index.
4. **Model Training**: Runs `autoencoder_train.py` to pre-train our anomaly detection models on historical claim records.

## Key Details
- **Build Manifest**: `iris.script`
- **Namespace Creator Class**: `iris/installer.cls`
- **Model Training Trigger**: Invokes `autoencoder_train.py` during build time.
- **HNSW Vector Builder**: Dynamically compiled using raw SQL DDL executions inside the Engine setup class.

## See Also
[[Installation Guide]] · [[HNSW Vector Index]] · [[Autoencoder Architecture]]