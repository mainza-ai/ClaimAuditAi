# Contest Alignment

> ClaimAuditAI is strategically architected to fulfill and exceed all competitive criteria of the InterSystems Programming Contest.

To maximize competitive advantages and secure high judge evaluation scores, ClaimAuditAI uses every key advanced capability of the InterSystems IRIS for Health platform:

| Feature Criteria | Contest Score Weight | ClaimAuditAI Specific Implementation |
| :--- | :---: | :--- |
| **Vector Search** | High | Dynamic SQL search using native `VECTOR_COSINE` against an HNSW index in `%SYS`. |
| **Embedded Python** | High | Execution of PyTorch Autoencoders and NetworkX directed graphs directly in IRIS memory. |
| **LLM & AI Hub** | High | Multi-agent `%AI.Agent` orchestrations and `%AI.ToolSet` dynamic LLM gateways. |
| **FHIR Server** | Medium | Custom strategy `RepoManager` implementing transactional FHIR R4 interceptors. |
| **ZPM/IPM Packager** | Medium | Single-command installation using ZPM `module.xml` and automated installer classes. |

## Key Details
- **Primary Namespace**: `INTEROP`
- **IRIS Native Toolsets**: `%AI.Agent`, `%AI.ToolSet`, `%AI.Tool`
- **Vector Datatype**: `VECTOR(DOUBLE, 384)`
- **Core Library Paths**: Embedded Python accessing host packages compiled under `/usr/irissys/mgr/python`.

## See Also
[[What is ClaimAuditAI]] · [[System Architecture Overview]] · [[ZPM Packaging and module.xml]]