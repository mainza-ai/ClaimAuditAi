# Data Classes

> Persistent and utility classes in the `ClaimAudit.Data` namespace that support chat history, background adjudication, graph visualization, and diagnostic tooling.

## ChatHistory (`ClaimAudit.Data.ChatHistory`)

Persistent chat message store for the AI audit assistant chat interface.

### Schema

| Property | Type | Max Length | Description |
|----------|------|:----------:|-------------|
| `ClaimId` | `%String` | — | Claim identifier this message belongs to (indexed) |
| `Role` | `%String` | — | Message role: `"user"`, `"assistant"`, or `"system"` |
| `Content` | `%String` | 16,000 | Message text content |
| `Timestamp` | `%String` | — | ISO 8601 timestamp of the message |

### SQL Table

```
ClaimAudit_Data.ChatHistory (ClaimId, Role, Content, Timestamp)
```

Indexed on `ClaimId` for efficient history retrieval.

### Methods

| Method | Description |
|--------|-------------|
| `SaveMessage(claimId, role, content, timestamp)` | Creates and persists a new chat message record |
| `GetHistory(claimId)` | Returns ordered `DynamicArray` of `{role, content, timestamp}` objects |

### API Endpoints

- `GET /chat/history/:id` — Returns `GetHistory()` for a claim
- `POST /chat/history/:id` — Calls `SaveMessage()` with a new message

---

## Queue (`ClaimAudit.Data.Queue`)

Background adjudication queue for asynchronous claim processing.

### Schema

| Property | Type | Max Length | Description |
|----------|------|:----------:|-------------|
| `ClaimResponseId` | `%String` | — | FHIR ClaimResponse resource ID (unique index) |
| `Status` | `%String` | — | Queue status: `"pending"`, `"processing"`, `"completed"`, `"failed"`, `"dead-letter"` |
| `CreatedAt` | `%String` | — | ISO 8601 timestamp of enqueue |
| `ProcessedAt` | `%String` | — | ISO 8601 timestamp of processing completion |
| `ErrorDetails` | `%String` | 16,000 | Error message if processing failed |
| `RetryCount` | `%Integer` | — | Number of processing attempts so far |
| `MaxRetries` | `%Integer` | — | Maximum retry attempts before dead-letter (default 3) |
| `DeadLetterAt` | `%String` | — | ISO 8601 timestamp when moved to dead-letter queue |
| `IsDeadLetter` | `%Boolean` | — | Flag indicating item is in the dead-letter queue |

### SQL Table

```
ClaimAudit_Data.Queue (ClaimResponseId, Status, CreatedAt, ProcessedAt, ErrorDetails)
```

Indexed on `ClaimResponseId` (unique) and `Status` for efficient queue iteration.

### Methods

| Method | Description |
|--------|-------------|
| `Enqueue(claimResponseId)` | Creates a new pending queue entry, or resets an existing entry to `"pending"`. Wrapped in `TSTART/TCOMMIT` with a node-level lock (`^ClaimAuditAI("QueueLock", claimResponseId)`, 10s timeout) to prevent concurrent enqueues |
| `MoveToDeadLetter(id)` | Moves a failed item to dead-letter status (`IsDeadLetter=1`, `DeadLetterAt=now`) |
| `RequeueFromDeadLetter(id)` | Resets a dead-letter item back to `"pending"` with `RetryCount=0` for reprocessing |
| `Clear()` | Kills all queue globals and resets state |

### Lifecycle

```
Claim submitted
    │
    ▼
Enqueue(ClaimResponseId)
(TSTART + Lock + Insert/Update + Unlock + TCOMMIT)
    │
    ▼
┌───────────────────────────────────────┐
│ WorkerLoop() (background job)         │
│   TSTART                              │
│   Lock ^ClaimAuditAI("QueueProcessLock") │
│   Poll Queue WHERE Status=pending     │
│   → ExecuteAdjudication()             │
│   → Success  → Status=completed       │
│   → Failure  → RetryCount++           │
│                › RetryCount≥MaxRetries →│
│                  MoveToDeadLetter()   │
│   TCOMMIT / TROLLBACK                 │
│   Unlock                              │
└───────────────────────────────────────┘
```

The background worker is spawned by `Engine.cls` and loops indefinitely, processing queued claims sequentially. Each cycle uses `TSTART/TCOMMIT` atomicity and a process-level lock to prevent concurrent workers from processing the same queue item. See [[Orchestration - AI Hub]] for the WorkerLoop architecture.

---

## GraphStore (`ClaimAudit.Data.GraphStore`)

Global-based persistent graph store for the provider-patient referral network, independent of the in-memory NetworkX graph used by Tier 3.

### Global Schema

```
^ClaimAuditGraph("node", id)       = $ListBuild(type, name, address?)
^ClaimAuditGraph("edge", patientId, providerNPI) = $ListBuild(amount, date)
```

- **Nodes**: Two types — `"patient"` (with name) and `"provider"` (with name + address).
- **Edges**: Directed from patient to provider, storing the billed amount and service date.

### Methods

| Method | Description |
|--------|-------------|
| `UpsertPatient(patientId, name)` | Add or update a patient node |
| `UpsertProvider(npi, name, address)` | Add or update a provider node |
| `UpsertEdge(patientId, providerNPI, amount, date)` | Add or update a claim edge |
| `ExportGraphJSON()` | Full graph export as Cytoscape.js-compatible JSON with built-in insight detection |
| `ClearAll()` | Clears all graph data (`Kill ^ClaimAuditGraph`) |

### Export Format (Cytoscape.js)

The `ExportGraphJSON()` method returns:

```json
{
  "nodes": [
    { "data": { "id": "patient-123", "label": "John Doe", "type": "patient" } },
    { "data": { "id": "provider-456", "label": "City Clinic", "type": "provider", "address": "123 Main St" } }
  ],
  "edges": [
    { "data": { "id": "edge-123-456", "source": "patient-123", "target": "provider-456",
                "label": "claim", "amount": 1500.00, "date": "2025-01-15" } }
  ],
  "insights": [
    { "type": "address_collision", "severity": "critical",
      "message": "Address collision: 3 providers at same address",
      "providerId": "provider-789" }
  ],
  "nodeCount": 2,
  "edgeCount": 1,
  "insightCount": 1
}
```

### Built-in Insight Detection

`ExportGraphJSON()` automatically detects **address collisions** — multiple providers sharing the same physical address. This is reported as a `"critical"` severity insight and flagged in the Tier 3 network analysis.

### API Endpoint

- `GET /graph` — Returns `ExportGraphJSON()`

---

## Debug (`ClaimAudit.Debug`)

Diagnostic utility class for development and environment setup.

### Method

| Method | Description |
|--------|-------------|
| `GrantRolesToUnknownUser()` | Grants fine-grained roles (`%DB_INTEROP-CODE`, `%DB_INTEROP-DATA`, `%HS_DB_INTEROP`, `%DB_INTEROPX0001R`, `%DB_INTEROPX0001V`, `%HS_ServiceRole`, `%HS_Administrator`) and schema-level SQL privileges (SELECT, INSERT, UPDATE, DELETE on `HSFHIR_X0001_S`, `HSFHIR_X0001_R`, `HSFHIR_X0001_V`, `ClaimAudit` schemas) to the `UnknownUser` account |
| `ToggleDebugLogging()` | Enables/disables per-request debug globals (`^ClaimAuditDebugUser`, `^ClaimAuditDebugOnAfterRequest`) for diagnosing FHIR interception issues |

The `%All` superuser role has been revoked from `UnknownUser`. Only the minimal roles and SQL privileges needed for CSP Gateway REST dispatch are granted. This utility exists to simplify initial container setup when running without a full Keycloak/IHF OAuth2 provider configured. It should not be used in production deployments.

---

## See Also

[[System Architecture Overview]] · [[Project Directory Structure]] · [[API Endpoints]]
