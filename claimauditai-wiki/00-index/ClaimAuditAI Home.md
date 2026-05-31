# ClaimAuditAI Home

> Master Map of Content (MOC) for ClaimAuditAI, an autonomous pre-payment payment integrity agent on InterSystems IRIS for Health.

ClaimAuditAI shifts the payment integrity paradigm from retrospective "pay-and-chase" to real-time pre-payment prevention directly inside the FHIR transaction loop. Utilizing native Vector Search, Embedded Python, and LLM-driven adjudication, the platform ensures clinical documentation justifies procedural charges before disbursement occurs.

## Map of Content

### 📂 01 - Platform Overview
- [[What is ClaimAuditAI]] — Executive summary of the autonomous payment integrity agent.
- [[Problem Statement]] — Deep-dive into healthcare fraud metrics and billing inefficiencies.
- [[Paradigm Shift - Reactive to Real-Time]] — Moving from retrospective "pay-and-chase" to active prevention.
- [[Contest Alignment]] — Strategic checklist of InterSystems bonus points.

### 📂 02 - Core Architecture
- [[System Architecture Overview]] — Technical tiers and database-level boundaries.
- [[Data Flow]] — Transactional sequence from Claim POST to mutated HTTP response.
- [[FHIR Interception Strategy]] — Overriding `HS.FHIRServer` methods pre-commit.
- [[RequestContext vs InteractionsContext]] — Memory context boundaries in strategy execution.
- [[Project Directory Structure]] — Standard file placements and component roles.

### 📂 03 - AI Adjudication Engines
- [[Three-Tier AI Engine Overview]] — Combined semantic, statistical, and graph threat scoring.
- [[Tier 1 - Semantic Clinical Auditor]] — Vector similarity matching between billed CPT codes and clinical text.
- [[Tier 2 - Statistical Outlier Profiler]] — Unsupervised PyTorch Autoencoders profiling claim anomalies.
- [[Tier 3 - Collusion Network Mapper]] — NetworkX relational collusion ring and fraud checks.
- [[Orchestration - AI Hub]] — `%AI.Agent`, `%AI.ToolSet`, and Model Context Protocol routing.

### 📂 04 - FHIR Integration
- [[FHIR Resource Lifecycle]] — Creation, validation, mutation, and database storage.
- [[FHIR SQL Builder Projections]] — Extracting transactional resources into dynamic schemas.
- [[HNSW Vector Index]] — Native high-performance database similarity indexing.
- [[VECTOR_COSINE Query Pattern]] — SQL syntax for matching clinical text embeddings.
- [[FHIR Resource Reference Table]] — Map of operational resources and their linkages.

### 📂 05 - Machine Learning & Mathematics
- [[Autoencoder Architecture]] — Bottle-necked neural networks for reconstruction loss.
- [[Reconstruction Loss Formula]] — Mathematical formulation of the outlier threat score.
- [[Dynamic Threshold Logic]] — Specialty-specific outlier classification limits.
- [[Embedded Python in IRIS]] — Direct system-level invocation of python packages.
- [[NetworkX Graph Construction]] — Entity-relation modeling at the transaction layer.

### 📂 06 - Installation & Provisioning
- [[Prerequisites]] — System requirements, Docker settings, and hardware baselines.
- [[Installation Guide]] — Execution steps for environment building and compilation.
- [[Environment Variables Reference]] — Master table of `.env` configurations.
- [[Docker Configuration]] — Python module caching and volume mount settings.
- [[FHIR Server Provisioning]] — Management Portal setup and `/interop/fhir/r4` routing.
- [[Initialization Script]] — Build-time (`iris.script`) and runtime (`init_iris.sh`) setup flows.

### 📂 07 - API Reference
- [[Endpoint Reference]] — Interactive URL structure and authentication headers.
- [[API Endpoints]] — Complete list of REST endpoints with response shapes.
- [[ClaimResponse - HOLD vs Pass]] — Output shapes of pended versus disbursed claims.
- [[OperationOutcome Structure]] — Error schemas and strict FHIR regex pattern matches.
- [[MCP Handshake and Tool Discovery]] — Handshaking protocols for agent orchestration.

### 📂 08 - Testing & Validation
- [[Testing Overview]] — Verification suites and live mock bundle ingestion.
- [[Simulating Tier 1 - Upcoding]] — Mock bundles triggering CPT-text semantic discrepancy.
- [[Simulating Tier 2 - Unbundling]] — Financial profiles triggering statistical outlier loss.
- [[Simulating Tier 3 - Collusion]] — Graph referrals triggering collision ring flags.
- [[Verifying Index and Model Readiness]] — Status validations for ML models and indexes.

### 📂 09 - Troubleshooting
- [[Troubleshooting Overview]] — Diagnostic entry point for platform issues.
- [[Container Startup Failures]] — Resolving compilation and permission errors in Docker.
- [[FHIR Server 404]] — Troubleshooting incorrect strategy endpoints and namespace setups.
- [[InteractionsStrategy Not Firing]] — Checking custom RepoManager strategy bindings.
- [[Autoencoder Not Detecting Anomalies]] — Tuning PyTorch bottleneck layers and learning rates.
- [[Vector Search Returns No Results]] — Debugging TO_VECTOR conversion syntax and empty tables.
- [[AI Hub Tool Invocation Failures]] — Troubleshooting timeout loops and empty tool definitions.
- [[MCP Handshake Failure]] — Checking JSON-RPC transport and local shell constraints.
- [[Embedded Python Import Errors]] — Managing CSP jobs and worker class caching.
- [[FHIR SQL Builder Projection Gaps]] — Auditing task logs and transformation schemas.
- [[Blank UI Due to API Error Responses]] — Fixing `.filter()` crashes from API error JSON.
- [[ObjectScript SQL Single-Quote Consumption]] — Solving `%Get` errors from stripped SQL quotes.
- [[Seed Data Disposition Validation]] — Fixing emoji/CRLF validation failures in FHIR strings.
- [[iris.script Indentation Pitfalls]] — Continuation line issues causing silent setup failures.
- [[Claim Amounts Always $0]] — Claim resources not persisted by interceptor; total not stored in ClaimResponse.
- [[ClaimResponse FHIR Validation]] — `total` field must use BackboneElement array, not Money object.
- [[LLM Provider Connection Failures]] — NVIDIA_API_KEY invisible to Embedded Python; runtime settings via `.llm_settings.json`.
- [[Claim Actions Silently Fail]] — FHIR datetime extension format causes silent PUT rejection.
- [[Rejected Claims Missing From Ledger]] — GetLedger excluded `status='cancelled'` tasks.
- [[Dashboard Metrics Stale After Actions]] — Missing `refetchInterval`, stale cache on navigation.
- [[Dashboard Daily Counts Always Zero]] — `CAST(_lastUpdated AS DATE)` incompatibility.
- [[Theme Not Applied on Page Load]] — `applyTheme()` not called on store initialization.
- [[Admin Routes Return 401]] — IRIS CSP blocks `/admin/` path prefix.
- [[LLM API Key Lost on Save]] — Settings file overwrite and key name mismatch.
- [[Autoencoder Trains on Random Noise]] — Synthetic noise fallback when < 10 real claims.
- [[Bundle Claims Not Intercepted]] — OnBeforeRequest only checks `Type="Claim"`.
- [[Collusion Graph Performance Degradation]] — Unbounded `nx.simple_cycles()` exponential blowup.

### 📂 10 - Platform Security
- [[Security Overview]] — Safeguarding PHI and local configuration keys.
- [[API Key Handling]] — Credentials hygiene and `.env` isolation.
- [[PHI and LLM Boundary]] — Strict rules on external vectorization and prompts.
- [[IRIS Role-Based Access Control]] — Securing patientdata schemas and CallIn services.

### 📂 11 - Packaging & Deployment
- [[Deployment Overview]] — Staging configurations for production rollouts.
- [[ZPM Packaging and module.xml]] — Packaging ClaimAuditAI for the InterSystems Package Manager.
- [[Online Demo Hosting]] — Cloud hosting configuration and public gateway settings.
- [[Developer Article Checklist]] — Criteria for contest community publication.
- [[YouTube Walkthrough Checklist]] — Content flow for dynamic video presentation.

### 📂 12 - Reference Material
- [[Glossary]] — Dynamic reference of medical, financial, and AI terminology.

## See Also
[[What is ClaimAuditAI]] · [[System Architecture Overview]] · [[Three-Tier AI Engine Overview]]