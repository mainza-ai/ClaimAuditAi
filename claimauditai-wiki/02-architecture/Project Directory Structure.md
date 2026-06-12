# Project Directory Structure

> The codebase layout organizes ObjectScript strategy packages, Embedded Python algorithms, seed samples, and configuration manifests into clean, distinct directories.

The directory layout of the ClaimAuditAI project conforms to ZPM and Docker container deployment patterns:

```
claimauditai/
├── docker-compose.yml    # Container orchestration and port bindings
├── Dockerfile            # Python dependency caching and image staging
├── requirements.txt      # Python packages (torch, sentence-transformers, etc.)
├── module.xml            # InterSystems Package Manager deployment details
├── merge.cpf             # Database CPF merge configurations
├── samples/              # Test vectors and clinical progress bundles
│   ├── sample_claim.json
│   └── sample_patient_bundle.json
├── src/                  # Strategy implementation package
│   ├── cls/
│   │   └── ClaimAudit/           # Root ObjectScript package
│   │       ├── FHIR/             # Strategy, RepoManager, and Interceptor classes
│   │       ├── AI/               # Engine, Agent, and Toolset definitions
│   │       ├── REST/             # Router, Auth, and admin endpoints
│   │       └── Data/             # ChatHistory, GraphStore, Queue, Debug
│   └── python/                 # Embedded Python analytics engines
│       ├── agent_orchestrator.py
│       ├── agent_graph.py       # Pydantic Graph FSM nodes
│       ├── agent_tools.py       # Tool registry for ReAct agent
│       ├── nlp_auditor.py
│       ├── autoencoder_train.py
│       ├── graph_analyzer.py
│       ├── tier_orchestrator.py # Circuit breaker, sequential tier execution
│       ├── llm_router.py        # Multi-provider LLM routing + rate limiter
│       ├── dx_procedure_validator.py  # Diagnosis-Procedure compatibility validation
│       └── mcp_server.py        # FastMCP terminology server
```

## Key Details
- **ObjectScript Namespace**: `ClaimAudit.*`
- **ZPM Module Name**: `claim-audit-ai`
- **Python Destination Directory**: `/home/irisowner/dev/src/python`
- **Dependencies Directory**: System python libraries installed under `/usr/irissys/mgr/python`.

## See Also
[[System Architecture Overview]] · [[ZPM Packaging and module.xml]] · [[Installation Guide]]