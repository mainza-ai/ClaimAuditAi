# Installation Guide

> The installation process builds the Docker containers, initializes the IRIS database, compiles the strategy classes, and trains the machine learning models.

Follow these step-by-step instructions to deploy the platform:

### 1. Clone the Project Repository
```bash
git clone https://github.com/mainza-ai/ClaimAuditAi.git
cd claimauditai
```

### 2. Configure Environment Variables
Create your local environment file from the provided template:
```bash
cp .env.example .env
```
Open `.env` and add your Nvidia API credentials:
```env
LLM_PROVIDER=nvidia
NVIDIA_API_KEY=your-nvapi-key-here
```

### 3. Spin Up the Container Stack
```bash
docker-compose up -d --build
```

The build sequence compiles the custom Interactions strategy classes, initializes the vector database indexes, and trains the baseline PyTorch autoencoder model.

## Key Details
- **Build Command**: `docker-compose up -d --build`
- **IRIS Verification Command**: `docker exec -it claimaudit-iris iris session IRIS -U INTEROP`
- **Primary Operational Endpoint**: `http://localhost:52773/fhir/r4`
- **ZPM Module Auto-Compilation**: Handled by the initialization scripts during build time.

## See Also
[[Prerequisites]] · [[Environment Variables Reference]] · [[Initialization Script]]