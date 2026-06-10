# Terminology MCP Server

> A Model Context Protocol (MCP) server built with Python's FastMCP framework, providing real-time medical terminology lookup and validation tools.

As part of the ClaimAuditAI contest enhancements, we implemented a dedicated FastMCP-compliant terminology server to resolve CPT and ICD-10 medical codes and perform diagnosis-procedure compatibility checks.

## 🛠️ Exposed Tools

The terminology MCP server exposes the following JSON-RPC tools:

1. **`lookup_cpt_code(code: str) -> str`**
   - **Purpose**: Translates a 5-digit CPT (Current Procedural Terminology) code into its full, human-readable clinical procedure description.
   - **Example**: `99291` -> `CPT 99291: Critical care, evaluation and management of the unstable critically ill or critically injured patient; first 30-74 minutes.`

2. **`lookup_icd_code(code: str) -> str`**
   - **Purpose**: Translates an ICD-10-CM (International Classification of Diseases, 10th Revision, Clinical Modification) diagnosis code into its clinical definition.
   - **Example**: `I25.10` -> `ICD I25.10: Atherosclerotic heart disease of native coronary artery without angina pectoris.`

3. **`validate_codes(icd_code: str, cpt_code: str) -> str`**
   - **Purpose**: Runs a diagnosis-procedure compatibility validation to check if the billed procedure is medically justified by the diagnosis.
   - **Example**: Check `I25.10` (heart disease) and `33510` (coronary bypass) -> returns validation status confirming compatibility.

## 🚀 Running the Server

The server is implemented in [mcp_server.py](file:///Users/mck/Desktop/claimauditai/src/python/mcp_server.py) and runs natively using FastMCP. It is installed inside the `claimaudit-iris` Docker container.

To start the server via command line:
```bash
mcp dev src/python/mcp_server.py
```

## See Also
[[MCP Handshake and Tool Discovery]] · [[Orchestration - AI Hub]] · [[Embedded Python in IRIS]]
