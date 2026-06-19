# Testing Overview

> Testing ClaimAuditAI involves submitting mock patient progress notes and simulating upcoding, unbundling, and referral fraud vectors.

To verify our payment integrity engines and complete end-to-end workflows, we can execute our automated Python E2E script from the host against the dockerized services:

```
Reset Database ──> Seed Data (LLM Bypass) ──> Fetch Held Queue ──> View Claim Detail (JIT LLM Report) ──> Auditor Escalation ──> Director Approval ──> Verify Graph/Health/Backup
```

Testing asserts that:
1. **Clinical Narrative Ingestion**: Decodes Base64 progress notes and indexes them in our vector database using SentenceTransformers.
2. **Real-Time Interception**: The strategy interceptor catches anomalous claim profiles pre-payment and routes them.
3. **Response Mutation**: The outgoing HTTP status is mutated to `202 Accepted` and hold resources are persisted.
4. **JIT LLM Generation**: When retrieving claim details, the system dynamically invokes the LLM (if not already cached) to build a detailed 3-tier adjudication report.
5. **Privilege Overrides**: Auditor escalates, and Director overrides and approves the pended claim.

## Key Details
- **Primary Test Script**: `real_world_e2e_tests.py` (located in the `/scratch` directory).
- **Execution Command**:
  ```bash
  .venv/bin/python scratch/real_world_e2e_tests.py
  ```
- **Authentication Credentials**: JWT Bearer tokens dynamically retrieved during persona login (`admin`, `auditor`, `director`).
- **Base Verification URL**: `http://localhost:52773`
- **Output Assertions**: Verification of the `outcome` (`"complete"`), task completion, cytoscape graph nodes, and system health status.

## Automated Unit Tests

In addition to E2E integration tests, ClaimAuditAI maintains comprehensive unit test coverage for both backend and frontend layers.

### Backend Python Unit Tests (pytest)
- **Framework**: `pytest` running inside the local `.venv`.
- **Command**:
  ```bash
  .venv/bin/pytest
  ```
- **Coverage**: Covers `llm_router` settings cache, parser, rate limiting, `nlp_auditor` sentence embeddings, `graph_analyzer` cycle detection, `autoencoder_train` 8-dimensional features and model training, `agent_graph` Pydantic Graph FSM node transitions and fallback workflows, `dx_procedure_validator` CPT/ICD prefix matching rules, and `ClaimAudit.Data.Queue` dead-letter queue, retry, and requeue database capabilities.

### Frontend Unit Tests (vitest)
- **Framework**: `vitest` with `@vitest/coverage-v8` coverage checking.
- **Command**:
  ```bash
  cd ui && npm test
  ```
- **Coverage**: Verifies component rendering, state changes, role checking permissions, and claim layout formatting.

## See Also
[[Simulating Tier 1 - Upcoding]] · [[Simulating Tier 2 - Unbundling]] · [[Simulating Tier 3 - Collusion]]