# AI Hub Tool Invocation Failures

> AI Hub tool invocation failures occur when external LLM connections time out or when process-private global variables are cleared prematurely.

### Symptom
The payment integrity engine runs normally, but `%AI.Agent` calls time out, preventing the creation of the pended `ClaimResponse` resource.

### Diagnostic Steps
1. **Check Container Network Access**: Verify that the container can access the host or external internet resources:
   ```bash
   docker exec -it claimaudit-iris curl -I https://integrate.api.nvidia.com
   ```
2. **Inspect Process-Private Globals**: Check if `^||ClaimAuditFlag` is populated during the request lifecycle.

### Resolution
1. **Increase API Timeout Limits**: Open `agent_orchestrator.py` and increase the OpenAI client timeout limit to at least **15.0 seconds**.
2. **Check API Keys**: Ensure that your `.env` contains the correct Nvidia API keys and that they are correctly loaded by Docker.

## See Also
[[Troubleshooting Overview]] · [[Orchestration - AI Hub]] · [[Environment Variables Reference]]