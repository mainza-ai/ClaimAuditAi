# MCP Handshake and Tool Discovery

> The Model Context Protocol (MCP) handshake allows our cognitive AI Agent to discover and execute local database-level analytical tools.

The platform exposes its analytical engines to the `%AI.Agent` using the **Model Context Protocol (MCP)**. This handshake allows the agent to dynamically discover and run our three payment integrity tiers as tools:

```
%AI.Agent ──> [JSON-RPC Handshake] ──> Tool Discovery ──> Native SQL & PyTorch Execution
```

During initialization, the agent connects to the local MCP gateway, which returns our available database tools:
1. `vector_similarity`: Executes native SQL vector search queries.
2. `autoencoder_outlier`: Runs PyTorch reconstruction loss predictions.
3. `graph_collusion`: Runs NetworkX referral cycle checks.

This protocol ensures our cognitive agent can query the database and execute complex machine learning models dynamically using a standardized API interface.

## Key Details
- **Protocol Standard**: Model Context Protocol (MCP).
- **Discovery Payload**: JSON-RPC schema definitions.
- **Exposed Tools**: `vector_similarity`, `autoencoder_outlier`, `graph_collusion`.
- **Orchestrator Binding**: Linked using `%AI.ToolSet` wrappers in the `INTEROP` namespace.

## See Also
[[Orchestration - AI Hub]] · [[Embedded Python in IRIS]] · [[MCP Handshake Failure]]