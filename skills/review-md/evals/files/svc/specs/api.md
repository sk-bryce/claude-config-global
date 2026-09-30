# ledgerd HTTP API specification

This is the source of truth for the ledgerd HTTP API, version 2. `docs/api.md` is generated from
it.

## Conventions

- Request and response bodies are JSON.
- Amounts are integers in minor units (cents for USD).
- A write may carry an `Idempotency-Key` header. The server applies a write with a key it has
  already seen only once and returns the original response.

## Endpoints

| Method | Path | Behavior | Success status |
| --- | --- | --- | --- |
| POST | `/v2/entries` | Append one entry. The response body holds the new entry's `id`. | `201 Created` |
| GET | `/v2/accounts/{id}/balance` | Return the account's current balance. | `200 OK` |
| GET | `/v2/accounts/{id}/entries` | List the account's entries, newest first. `limit` defaults to 50; the maximum is 500. | `200 OK` |
| POST | `/v2/drain` | Stop accepting writes and flush the write queue to the shards. | `202 Accepted` |
| GET | `/healthz` | Report liveness. | `200 OK` |

## Entry fields

| Field | Type | Required |
| --- | --- | --- |
| `account` | string | yes |
| `amount` | integer | yes |
| `memo` | string | [optional] |
