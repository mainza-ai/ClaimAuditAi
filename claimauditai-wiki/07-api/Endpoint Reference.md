# Endpoint Reference

> The API endpoint provides RESTful endpoints to ingest patient documentation and submit claims for real-time adjudication.

All operations are exposed through the transactional FHIR server endpoint `/interop/fhir/r4`:

### Ingestion & Adjudication Endpoints

| HTTP Method | Request Path | Target Resource | Purpose |
| :--- | :--- | :--- | :--- |
| `POST` | `/interop/fhir/r4` | `Bundle` (Transaction) | Bulk-ingests patient records and progress notes. |
| `POST` | `/interop/fhir/r4/Claim` | `Claim` | Submits a claim for real-time AI payment integrity analysis. |
| `GET` | `/interop/fhir/r4/ClaimResponse/<id>`| `ClaimResponse` | Retrieves the adjudication results and hold reports. |
| `GET` | `/interop/fhir/r4/Task/<id>` | `Task` | Retrieves the generated manual audit routing task. |

> [!note]
> All requests must include standard Basic Authentication headers (`Authorization: Basic X1NZU1RFTTpTWVM=`) and use the `application/fhir+json` content type.

## Key Details
- **Root URL**: `http://localhost:52773/interop/fhir/r4`
- **Content-Type Header**: `application/fhir+json`
- **Auth Scheme**: Basic Authentication (`_SYSTEM` / `SYS` credentials by default).
- **Output Status**: Returns `201 Created` for normal submissions, or `202 Accepted` for pended anomaly holds.

## See Also
[[ClaimResponse - HOLD vs Pass]] · [[OperationOutcome Structure]] · [[FHIR Resource Reference Table]]