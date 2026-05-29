# MCP Handshake Failure

> MCP handshake failures occur when local port conflicts prevent JSON-RPC communication between the AI Agent and the MCP server.

### Symptom
The `%AI.Agent` throws communication exceptions during initialization and cannot discover the exposed database tools.

### Diagnostic Steps
1. **Check Exposed Ports**: Verify that port `8080` is open and active on the host machine:
   ```bash
   netstat -an | grep 8080
   ```
2. **Inspect MCP Server Logs**: Check the logs of the running MCP server inside your VM.

### Resolution
Update your tool discovery configuration to use the correct local hostname or IP address:
```json
// In mcp config mappings
{
  "mcpServers": {
    "claimaudit-server": {
      "command": "node",
      "args": ["/home/irisowner/dev/src/js/mcp_server.js"],
      "env": {
        "IRIS_PORT": "1972"
      }
    }
  }
}
```

## See Also
[[Troubleshooting Overview]] · [[MCP Handshake and Tool Discovery]] · [[Docker Configuration]]