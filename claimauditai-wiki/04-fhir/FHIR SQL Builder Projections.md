# FHIR SQL Builder Projections

> The FHIR SQL Builder projects complex, nested FHIR JSON resources into flat, relational SQL tables to enable high-performance analytics.

The projection process uses the native InterSystems FHIR SQL Builder tool, executing in three distinct phases:

```
FHIR JSON Resources ──> [Analysis] ──> [Transformation] ──> [Projection] ──> Relational Tables
```

1. **Analysis**: Evaluates JSON resource properties and calculates structural schemas.
2. **Transformation**: Maps nested arrays (e.g. CPT billing codes, diagnoses) to virtual tables.
3. **Projection**: Generates physical database projections (`ClaimProjections`, `PatientProjections`, `ProviderProjections`) under the `ClaimAudit` schema.

These projected tables allow our Embedded Python PyTorch and NetworkX engines to query clinical and financial datasets using standard SQL.

## ⚙️ Pre-Configured Projections & Helper
To enable immediate setup and standardized analytics, the platform provides:
- **`fhirsql/projections.json`**: Contains configuration metadata for projecting `Claim` and `ClaimResponse` resources. This file can be imported directly into the InterSystems FHIR SQL Builder Management Portal GUI to spin up relational projections.
- **`ClaimAudit.FHIR.SQLBuilderHelper`**: An ObjectScript class that wraps dynamic SQL queries against the projected FHIR SQL schema. It handles reading mapped billing properties (like CPT codes, ICD diagnoses, amounts, and dates) with robust fail-safes and query builders.

## Key Details
- **Target Schema**: `ClaimAudit` (e.g. `ClaimAudit.ClaimProjections`)
- **Generated Projections**: `ClaimProjections`, `PatientProjections`, `ProviderProjections`.
- **Sync Trigger**: Automated transactional projections managed by the IRIS database compiler.
- **Specialty Mapping**: Dynamically extracted from provider records to compute dynamic anomaly thresholds.

## See Also
[[System Architecture Overview]] · [[HNSW Vector Index]] · [[VECTOR_COSINE Query Pattern]]