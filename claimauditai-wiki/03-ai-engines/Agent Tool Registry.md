# Agent Tool Registry

> The Tool Registry (`agent_tools.py`) enables the ReAct agent loop to call audit engines, terminology lookups, and database queries through auto-generated function schemas.

The registry uses a decorator-based pattern: any function decorated with `@registry.register` has its signature and docstring introspected to produce an OpenAI-compatible tool schema. This allows the LLM to discover and invoke tools without hardcoded configuration.

## Architecture

```
LLM decides to call a tool
        │
        ▼
┌──────────────────┐
│ run_chat_agent() │  (in llm_router.py)
│   max 3 steps    │
└──────────────────┘
        │
        ▼
┌──────────────────┐
│ registry.execute │  (in agent_tools.py)
│  (name, args)    │
└──────────────────┘
        │
        ▼
┌──────────────────┐
│ Registered tool  │
│ function call    │
└──────────────────┘
        │
        ▼
Result returned as
JSON string → LLM
```

The agent loop in `run_chat_agent()` runs up to 3 steps: the LLM decides whether to respond or call a tool, the registry executes the tool, and the result is fed back for the next step.

## Registered Tools

### Terminology Lookups

| Tool | Function | Description |
|------|----------|-------------|
| `lookup_cpt_code` | `mcp_server.lookup_cpt_code()` | Returns official description for a 5-digit CPT code |
| `lookup_icd_code` | `mcp_server.lookup_icd_code()` | Returns official description for an ICD-10 code |
| `validate_clinical_edits` | `mcp_server.validate_diagnosis_procedure()` | Checks ICD-CPT compatibility |

### Audit Executions

| Tool | Function | Description |
|------|----------|-------------|
| `run_nlp_audit` | `nlp_auditor.verify_clinical_validity()` | Runs Tier 1 semantic clinical note search |
| `run_anomaly_audit` | `autoencoder_train.evaluate_claim_anomaly()` | Runs Tier 2 autoencoder anomaly detection (5 features) |
| `run_graph_audit` | `graph_analyzer.check_collusion_network()` | Runs Tier 3 collusion network analysis |

### Database Queries

| Tool | Function | Description |
|------|----------|-------------|
| `get_patient_history` | SQL via `iris.sql.prepare()` | Returns prior claim outcomes for a patient |
| `get_provider_history` | SQL via `iris.sql.prepare()` | Returns hold/approve/reject rates for a provider NPI |

## Schema Generation

The `ToolRegistry.register()` decorator uses Python's `inspect` module to build schemas automatically:

```
Function signature ──► Parameter names, types, defaults
       │
       ▼
Function docstring ──► Description (before "Args:" section)
       │
       ▼
OpenAI tool schema ──► { type: "function", function: { name, description, parameters } }
```

Parameter types are mapped: `str` → `"string"`, `float` → `"number"`, `int` → `"integer"`, `bool` → `"boolean"`, `list` → `"array"`. Parameters without defaults are marked as required.

## Tool Execution

`registry.execute(name, arguments)`:
1. Looks up the function by name
2. Calls it with `**arguments`
3. JSON-serializes dict/list results with `indent=2`
4. Returns errors as `"Error executing tool: ..."` strings

## Agent Loop Protocol

```
Step 1: System prompt + user question
        → LLM responds with tool_calls or final answer
Step 2: If tool_calls:
        → Execute each tool, append results as "role": "tool" messages
        → LLM evaluates results, may call more tools or give final answer
Step 3: Repeat up to max_steps=3
        → Return final content
```

## See Also

[[LLM Router Architecture]] · [[Orchestration - AI Hub]] · [[Three-Tier AI Engine Overview]]
