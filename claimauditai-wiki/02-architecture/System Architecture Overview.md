# System Architecture Overview

> The ClaimAuditAI architecture is a three-tiered clinical-financial payment integrity system running natively within the InterSystems IRIS for Health process memory.

The system bypasses typical network serialization gaps by staging all analytical operations directly inside the database kernel. A custom strategy interceptor captures incoming REST payloads, passing them to the clinical database and Embedded Python engines.

```
                       +---------------------------------------+
                       |          FHIR Client (REST)           |
                       +---------------------------------------+
                                           |
                                   POST /Claim (R4)
                                           v
+-----------------------------------------------------------------------------------+
| InterSystems IRIS for Health (Kernel Space)                                       |
|                                                                                   |
|  +-----------------------------+         +-------------------------------------+  |
|  | ClaimAudit.FHIRInterceptor  |-------->|   ClaimAudit.AI.Engine (Database)   |  |
|  |   (InteractionsStrategy)    |         |                                     |  |
|  +-----------------------------+         | - Vector Search Table               |  |
|                 |                        | - PatientProjections Table          |  |
|                 | (Anomalous)            +-------------------------------------+  |
|                 v                                           |                     |
|  +-----------------------------+                            | (Shared Memory)     |
|  |     202 Accepted Hold       |                            v                     |
|  |      Response Mutation      |         +-------------------------------------+  |
|  +-----------------------------+         |       Embedded Python Core          |  |
|                 |                        |                                     |  |
|                 +----------------------->| - PyTorch Autoencoder Anomaly       |  |
|            (Dispatches)                  | - NetworkX Graph referral loop      |  |
|                 |                        | - SentenceTransformers Vectorizer   |  |
|                 v                        +-------------------------------------+  |
|  +-----------------------------+                            |                     |
|  |   Auxiliary FHIR Storage    |                            v                     |
|  |  - Task (Urgent Review)     |<---------------------------+                     |
|  |  - CommunicationRequest     |                   Adjudicates                    |
|  +-----------------------------+                                                  |
+-----------------------------------------------------------------------------------+
```

## Key Details
- **Kernel Interceptor**: Extends `HS.FHIRServer.Storage.Json.Interactions`.
- **Database Engine**: Manages native HNSW vector indexes and dynamic SQL projections.
- **Embedded Python Layer**: Accesses PyTorch, NetworkX, and SentenceTransformers directly inside the database process.
- **AI Hub & FSM Orchestration**: Bridges native `%AI.Agent` calls with a type-safe Python **Pydantic Graph FSM** using `ClaimAudit.AI.AgentWrapper`.

## See Also
[[Data Flow]] · [[FHIR Interception Strategy]] · [[Project Directory Structure]]