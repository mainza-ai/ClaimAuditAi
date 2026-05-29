# 🏆 ClaimAuditAI: Autonomous Payment Integrity Agent for FHIR

ClaimAuditAI is a state-of-the-art payment integrity agent running natively on the **InterSystems IRIS for Health** platform. It shifts the healthcare auditing paradigm from retrospective "pay-and-chase" workflows to **autonomous, real-time, pre-payment prevention** at the database transaction layer.

Developed for the **InterSystems Programming Contest: AI Agents for FHIR**.

---

### 👤 Author
* **Mainza Kangombe** - [LinkedIn Profile](https://www.linkedin.com/in/mainza-kangombe-6214295/)

---

## 🧠 Core Architecture: Three-Tiered AI Reasoning Engine

ClaimAuditAI deploys a sophisticated, three-tiered reasoning engine executing concurrently within the database transaction lifecycle:

1. **Tier 1: Semantic NLP Vector Search (`nlp_auditor.py`)**
   - Generates 384-dimensional semantic embeddings using a local sentence-transformer.
   - Performs a native SQL `VECTOR_COSINE` search using an **HNSW** index in the IRIS kernel to check if billing descriptions semantically align with unstructured clinical progress notes in `DocumentReference`.
2. **Tier 2: Statistical Outlier Profiling (`autoencoder_train.py`)**
   - Natively trains an unsupervised **PyTorch** Autoencoder inside the database process to profile claim features and flags anomalies exceeding the 95th percentile reconstruction loss threshold.
3. **Tier 3: Collusion Network Mapping (`graph_analyzer.py`)**
   - Builds active referral networks using a **NetworkX** directed graph to detect geo-temporal leaps and referral collusion rings at the transaction layer.

---

## 🚀 Live Verification Walkthrough

Submit claims and simulate real-time adjudication:

1. **Ingest Clinical Narrative (Baseline Checkup)**
   ```http
   POST http://localhost:52773/interop/fhir/r4
   Content-Type: application/json
   <samples/sample_patient_bundle.json>
   ```
   *Note description: A patient visited for a routine yearly physical checkup.*

2. **Submit Anomalous Claim (CPT 99291 Complex Critical Care, $2,500.00)**
   ```http
   POST http://localhost:52773/interop/fhir/r4/Claim
   Content-Type: application/json
   <samples/sample_claim.json>
   ```

3. **Adjudication Outcome (HTTP 202 Accepted)**
   The interceptor detects the high-risk mismatch and automatically:
   - **Mutates the HTTP response** to `202 Accepted` with a pended `ClaimResponse` resource.
   - **Populates the `disposition` field** with an explainable markdown audit report authored by the LLM (Nvidia API or local Ollama).
   - **Registers a manual review `Task`** (ID: `12`) with `urgent` priority.
   - **Registers a hold `CommunicationRequest` notification** (ID: `13`) referencing both resources.

---

## 🛠️ Staging and Local Installation

1. **Clone the Repository**
   ```bash
   git clone https://github.com/mainza-ai/ClaimAuditAi.git
   cd claimauditai
   ```

2. **Configure Environment**
   Create a `.env` file from the example:
   ```bash
   cp .env.example .env
   ```
   *Defaults to cloud Nvidia GLM-5.1 or dynamically routes to local Ollama.*

3. **Build and Spin up Containers**
   ```bash
   docker-compose up -d --build
   ```
   The container automatically initializes the `INTEROP` namespace, registers ZPM packages, compiles custom strategy classes, pre-trains PyTorch autoencoders, and initializes the native HNSW vector index.

---

## 🏛️ Codebase Architecture

```
claimauditai/
├── .env                  # Configuration keys (Nvidia/Ollama/OpenAI)
├── docker-compose.yml    # Port forwarding and volume mapping
├── requirements.txt      # PyTorch, NetworkX, sentence-transformers, OpenAI
├── module.xml            # ZPM installation manifest
├── merge.cpf             # IRIS kernel merge (call-in enable)
├── samples/              # anomalous Claim and Clinical progress notes
├── iris/                 # Database installer manifest
├── src/
│   ├── cls/              # ObjectScript strategy, interceptor & AI Hub wrapper
│   └── python/           # Embedded Python Tier 1-3 AI engines
```

---

## 📜 License
This project is licensed under the MIT License.
