# Glossary

> Glossary of clinical, database, and machine learning terms used within the ClaimAuditAI ecosystem.

- **FHIR**: Fast Healthcare Interoperability Resources, the standard framework for exchanging healthcare data. See [[FHIR Resource Lifecycle]].
- **CPT**: Current Procedural Terminology, standardized codes used to report medical procedures. See [[Simulating Tier 1 - Upcoding]].
- **ICD-10**: International Classification of Diseases (10th Revision), codes used to classify diagnoses. See [[FHIR SQL Builder Projections]].
- **NPI**: National Provider Identifier, a unique 10-digit identification number for covered healthcare providers. See [[NetworkX Graph Construction]].
- **Upcoding**: Billing for a more expensive procedure than was actually performed. See [[Simulating Tier 1 - Upcoding]].
- **Unbundling**: Billing multiple CPT codes separately rather than using a single, comprehensive code. See [[Simulating Tier 2 - Unbundling]].
- **HNSW**: Hierarchical Navigable Small World, an algorithm used for high-performance vector search indexing. See [[HNSW Vector Index]].
- **Autoencoder**: An unsupervised neural network architecture used to compress and reconstruct data to identify anomalies. See [[Autoencoder Architecture]].
- **Reconstruction Loss**: The difference between the input vector and its reconstructed output, acting as our anomaly score. See [[Reconstruction Loss Formula]].
- **MCP**: Model Context Protocol, an open standard for connecting AI models to local tools and databases. See [[MCP Handshake and Tool Discovery]].
- **Embedded Python**: Direct execution of Python code and packages within the database process memory space. See [[Embedded Python in IRIS]].
- **ZPM/IPM**: InterSystems Package Manager, used to build, package, and distribute IRIS applications. See [[ZPM Packaging and module.xml]].
- **VECTOR_COSINE**: Native SQL function used to calculate the cosine similarity between two vectors. See [[VECTOR_COSINE Query Pattern]].
- **AI Hub**: The native InterSystems platform layer used to configure and orchestrate AI models. See [[Orchestration - AI Hub]].

## See Also
[[ClaimAuditAI Home]] · [[Three-Tier AI Engine Overview]] · [[FHIR Resource Reference Table]]