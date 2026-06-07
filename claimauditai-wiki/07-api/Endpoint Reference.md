# Endpoint Reference

> The API endpoint provides RESTful endpoints to ingest patient documentation and submit claims for real-time adjudication.

All operations are exposed through the transactional FHIR server endpoint `/fhir/r4`:

### Ingestion & Adjudication Endpoints

| HTTP Method | Request Path | Target Resource | Purpose |
| :--- | :--- | :--- | :--- |
| `POST` | `/fhir/r4` | `Bundle` (Transaction) | Bulk-ingests patient records, progress notes, or claims. |
| `POST` | `/fhir/r4/Claim` | `Claim` | Submits a claim for real-time AI payment integrity analysis. |
| `GET` | `/fhir/r4/ClaimResponse/<id>`| `ClaimResponse` | Retrieves the adjudication results and hold reports. |
| `GET` | `/fhir/r4/Task/<id>` | `Task` | Retrieves the generated manual audit routing task. |

> [!note]
> All requests must include either Bearer Authentication (`Authorization: Bearer <token>`) or standard Basic Authentication (`Authorization: Basic <base64(user:pass)>`) and use the `application/fhir+json` content type.

## Key Details
- **Root URL**: `http://localhost:52773/fhir/r4` (or port `8080` depending on container routing)
- **Content-Type Header**: `application/fhir+json`
- **Auth Scheme**: Bearer Token (JWT / SMART on FHIR) or Basic Authentication (`_SYSTEM` / `SYS` credentials by default).
- **Output Status**: Returns `201 Created` for normal, cleared submissions, or `202 Accepted` for pended anomaly holds (along with a hold `ClaimResponse` resource details).

## See Also
[[ClaimResponse - HOLD vs Pass]] · [[OperationOutcome Structure]] · [[FHIR Resource Reference Table]]