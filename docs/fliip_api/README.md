# Fliip API

Clients, contracts and services in this app are read-only copies of records in [Fliip](https://fliipapp.com), the studio's gym-management system. This folder explains the part of the Fliip API the app depends on, so you can work on the sync without calling the real API.

- **This file:** what the app calls, how, and the quirks to know about.
- **[reference.md](reference.md):** every endpoint and field in Fliip's OpenAPI spec (v1.2.0), including which fields can be null.
- **[examples/](examples/):** one example response per endpoint, with fake data. The shapes and types follow the spec.

The examples are documentation only. Specs never load them: they build the few fields they need inline and stub the API with WebMock (`spec/services/fliip_api/api_client_spec.rb`) or `instance_double(FliipApi::ApiClient)` (everything above the client).

## Endpoints the app uses

All calls go through `FliipApi::ApiClient` (`app/services/fliip_api/api_client.rb`), base URL `https://static.fliipapp.com/api/v2`.

| Endpoint | `ApiClient` method | Used by | Example |
|---|---|---|---|
| `GET /users/get?limit=&offset=` | `fetch_all_users` | `UserImporter`, `NewUserImporter` | [users_get.json](examples/users_get.json) |
| `GET /users/details/{user_id}` | `fetch_single_user` | `UserUpdater` (clients) | [users_details.json](examples/users_details.json) |
| `GET /staff/get` | `fetch_all_staff` | `UserImporter`, `NewUserImporter` | [staff_get.json](examples/staff_get.json) |
| `GET /staff/details/{user_id}` | `fetch_single_staff` | `UserUpdater` (staff) | [staff_details.json](examples/staff_details.json) |
| `GET /contracts/get/{user_id}`, `/get_future/…`, `/get_history/…` | `fetch_user_contracts`, `fetch_future_user_contracts`, `fetch_history_user_contracts` | `ContractSync` | [contracts_get.json](examples/contracts_get.json) |
| `GET /services/get/{user_id}`, `/get_future/…`, `/get_history/…` | `fetch_user_services`, `fetch_future_user_services`, `fetch_history_user_services` | `ServiceSync` | [services_get.json](examples/services_get.json) |

The payments, settings, visits and `/gate/*` endpoints are documented in `reference.md` but not used.

Which fields are stored: `user_attributes` in `UserSync::Base`, `contract_attributes` in `ContractSync` and `service_attributes` in `ServiceSync`. Everything else in a response is ignored.

## Authentication

The studio's API secret goes in the `Authorization` header (Fliip accepts the raw key or `Bearer <key>`; the app sends the raw key). The app reads it from `FLIIP_API_KEY` (`.env` locally) and `ApiClient.new` raises if it is missing.

## Quirks the app relies on

- **Paging.** Request `limit=100` plus `offset` until a page comes back short or empty. The spec documents a maximum of 250, but very high limits return `400 Bad Request` with an empty body. `/staff/get` is called without paging; the staff list is small.
- **Errors have no body.** 400, 401 and 403 responses are empty. `ApiClient` logs the status and returns `[]`, so an outage looks like "no data". `fetch_all_users` returns whatever pages it got before a failure, without logging.
- **Ids are numeric strings** (`"user_id": "123"`). The sync converts them with `to_i` into `remote_id`, `remote_contract_id` and `remote_purchase_id`.
- **Clients and staff share one shape.** `user_role` is `"user"` for clients; anything else is staff (`FliipUser#staff?`).
- **Several date formats:** `YYYY-MM-DD`, `YYYY-MM-DD HH:MM:SS` without a time zone, ISO 8601, and display strings in visits. Invalid dates become `nil`. Zoneless timestamps such as `purchase_date` are stored as UTC.
- **Booleans arrive as `"0"` / `"1"` strings** (`stop_payments`, `billed_at_purchase`, `online_enabled`).
- **Encoding.** Text sent as ISO-8859-1 converts correctly when the response declares its charset. Undeclared non-UTF-8 text reaches the database as invalid UTF-8 and the save fails.

The sync's open problems (silent failures, encoding, scale, reconciliation) are tracked in the Codebase Audit & Stabilization project.
