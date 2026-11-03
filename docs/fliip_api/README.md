# Fliip API

Clients, contracts and services in this app are read-only copies of records in [Fliip](https://fliipapp.com), the studio's gym-management system. This folder explains the part of the Fliip API the app depends on, so you can work on the sync without calling the real API.

- **This file:** what the app calls, how, and the quirks to know about.
- **[reference.md](reference.md):** every endpoint and field in Fliip's OpenAPI spec (v1.2.0), including which fields can be null.
- **[examples/](examples/):** one example response per endpoint, with fake data. The shapes and types follow the spec.

The examples are documentation only. Specs never load them: they build the few fields they need inline and stub the API with WebMock (`spec/services/fliip_api/client_spec.rb`) or `instance_double(FliipApi::Client)` (everything above the client).

## Endpoints the app uses

All calls go through `FliipApi::Client` (`app/services/fliip_api/client.rb`), base URL `https://static.fliipapp.com/api/v2`. It raises `FliipApi::NotFound` on 400 and `FliipApi::Unavailable` when retries run out; it never returns `[]` on failure.

| Endpoint | `Client` method | Example |
|---|---|---|
| `GET /users/get?limit=&offset=` | `client_pages`, `clients` | [users_get.json](examples/users_get.json) |
| `GET /users/details/{user_id}` | `client` | [users_details.json](examples/users_details.json) |
| `GET /staff/get?limit=&offset=` | `staff` | [staff_get.json](examples/staff_get.json) |
| `GET /staff/details/{user_id}` | `staff_member` | [staff_details.json](examples/staff_details.json) |
| `GET /services/get_history/{user_id}` | `services` | [services_get_history.json](examples/services_get_history.json) |
| `GET /contracts/get/{user_id}`, `/get_future/…`, `/get_history/…` | `contracts` | [contracts_get.json](examples/contracts_get.json) |

The payments, settings, visits and `/gate/*` endpoints, and `services/get` and `services/get_future`, are documented in `reference.md` but not used.

Which fields are stored: `FliipApi::Mapper` (`user`, `service`, `contract`). Everything else in a response is ignored. How the sync uses these calls is in `docs/adr/0001-fliip-sync-jobs.md`.

## Authentication

The studio's API secret goes in the `Authorization` header (Fliip accepts the raw key or `Bearer <key>`; the app sends the raw key). The app reads it from `FLIIP_API_KEY` (`.env` locally) and `Client.new` raises if it is missing.

## Quirks the app relies on

- **Paging.** Request `limit=100` plus `offset` until a page comes back short or empty. The spec documents a maximum of 250, but very high limits return `400 Bad Request` with an empty body. `/staff/get` takes the same paging.
- **Errors have no body.** 400, 401 and 403 responses are empty, so the status code is all there is to go on.
- **Unknown user vs no data.** The per-user endpoints return `400` (empty body) for a user id Fliip doesn't know, and `200 []` when the user has no services or contracts.
- **`/users/get` is sorted by `user_id`, newest first.** New clients are at the start of the first page.
- **Services: `get_history` returns everything.** It includes the active and suspended services from `get` and the planned ones from `get_future`, with identical values, so one call covers a user's services.
- **Contracts: the three endpoints don't overlap.** `get` returns active and suspended, `get_future` planned (with a `null` status), `get_history` inactive and cancelled. All three are needed.
- **No deletions are reported.** A service or contract deleted in Fliip (typically the same day it was created, before payment) simply stops being returned.
- **`user_status` doesn't reflect reality.** Clients with live services are often "inactive". Use service and contract statuses and dates instead.
- **`/gate/getChangedUsers` isn't a reliable change feed.** It only lists users who have a contract, Fliip documents it as profile changes only, and it doesn't report deletions or derived status changes.
- **Ids are numeric strings** (`"user_id": "123"`). The mapper converts them to integers in `remote_id`, `remote_contract_id` and `remote_purchase_id`.
- **Clients and staff share one shape.** `user_role` is `"user"` for clients; anything else is staff (`FliipUser#staff?`).
- **Several date formats:** `YYYY-MM-DD`, `YYYY-MM-DD HH:MM:SS` without a time zone, ISO 8601, and display strings in visits. Invalid dates become `nil`. Zoneless timestamps such as `purchase_date` are stored as UTC.
- **Booleans arrive as `"0"` / `"1"` strings** (`stop_payments`, `billed_at_purchase`, `online_enabled`).
- **Encoding.** Text sent as ISO-8859-1 converts correctly when the response declares its charset. Undeclared non-UTF-8 text reaches the database as invalid UTF-8 and the save fails.

The sync's open problems (silent failures, encoding, scale, reconciliation) are tracked in the Codebase Audit & Stabilization project.
