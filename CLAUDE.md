# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Internal staff app for Studio Santé Active, a fitness/health studio. Employees log training sessions ("séances") and consultations against client services that are mirrored from the **Fliip** gym-management API. Admins confirm sessions and consultations for payroll and adjust service usage. UI copy and validation messages are in **French**. App time zone is `Eastern Time (US & Canada)`.

Stack: Rails 8.0, Ruby 3.3.11, PostgreSQL (needs the `unaccent` extension), Devise, Hotwire (Turbo + Stimulus via importmap, so there is no Node build step), Bootstrap 5 compiled by `dartsass-rails` and served by Sprockets, simple_form, pg_search, Pagy, Solid Queue. Deployed on Render (`render.yaml`, `bin/render-build.sh`, which runs migrations and seeds on every build).

## Commands

```bash
bin/setup                       # install gems, prepare DB
bin/dev                         # dev server + Sass watcher (Procfile.dev); plain `bin/rails server` won't recompile CSS
bin/rails dartsass:build        # compile app/assets/stylesheets → app/assets/builds (gitignored; assets:precompile does this too)
bin/rails db:migrate
bundle exec rspec                                   # all specs
bundle exec rspec spec/models/session_spec.rb       # one file
bundle exec rspec spec/models/session_spec.rb:12    # one example by line
bundle exec rubocop                                 # lint (rubocop-rails-omakase)
bundle exec brakeman -q                             # security scan
bundle exec bundle-audit check --update             # known-vulnerable gems
bin/rails fliip:sync            # full Fliip → local DB sync (lib/tasks/fliip_sync.rake)
./bin/importmap pin <pkg>       # add a JS dependency
```

Tests use RSpec, FactoryBot (`spec/factories/`), Shoulda Matchers and Faker, with config in `spec/support/`. Request specs sign in with Devise's `sign_in`. The Fliip API is never called in specs: stub `FliipApi::ApiClient.new` with an `instance_double` (see `spec/services/fliip_api/user_sync/user_importer_spec.rb`). `spec/factories_spec.rb` lints every factory and trait. Coverage is still a safety net, not a full suite: models, role access, session CRUD and the sync are covered, controllers beyond those are not. Bullet is enabled in development only.

`FLIIP_API_KEY` must be set (loaded from `.env` via dotenv-rails). `FliipApi::ApiClient` calls `ENV.fetch` on it and raises if it is missing.

## Architecture

### Two kinds of "users"
- `User`: staff accounts (Devise). `role` enum: `employee`, `manager`, `admin`, `super_admin`. Sign-up requires a valid `SignupCode` (8 characters, expiring, consumed on create). An `active` flag blocks login, and `ApplicationController#logout_if_inactive` signs out deactivated users on every request.
- `FliipUser`: clients, read-only mirrors of Fliip. They have many `FliipContract`s and `FliipService`s and are keyed by `remote_id` (Fliip's id). Don't edit Fliip-owned fields locally, because the next sync overwrites them.

### Naming collision: `Session`
`Session` is a domain model (a booked training session), not an HTTP session. `SessionsController` / `resources :sessions` are this model's CRUD and are separate from Devise's `devise/sessions` login controller. The booking form lives at `seances/new` (`BookingsController#new`).

### Fliip sync (`app/services/fliip_api/`)
- `ApiClient` is a thin HTTParty wrapper over `https://static.fliipapp.com/api/v2`. On failure it logs the error and returns `[]`.
- `UserSync::Base#upsert_user` upserts a `FliipUser` by `remote_id`, then always runs `ContractSync` and `ServiceSync` (current, future and history endpoints). Services are upserted by `remote_purchase_id`.
- Entry points: `UserImporter` (full sync: admin "import clients" button and `rake fliip:sync`), `NewUserImporter` (new clients only: the "refresh clients" button on the booking page), `UserUpdater` (one client by `remote_id`).
- When a sync finishes, it calls `ServiceDefinition.create_missing_definitions!`.

### Session quota math (core business logic)
- `ServiceDefinition` is keyed by Fliip's `service_id` (non-standard PK/FK on both sides). It holds the `paid_sessions` / `free_sessions` allowance for a service type. Admins set these. New definitions are created with 0/0.
- `FliipService` computes usage. Allowed = definition + `bonus_sessions` from `ServiceUsageAdjustment`s. Used = sum of session `duration` + adjustment deltas. Remaining is clamped at 0. Values are floats because durations can be fractional.
- `Session` callbacks and validations on create: `session_type` is chosen automatically. It is `free` (an "absence") when the client was not present and enough free allowance remains, and `paid` otherwise. Quotas are enforced, cancelled services are rejected, the service must belong to the chosen client, and there is a ±30-day window around the service start/expiry dates.
- `Session` and `Consultation` both have a `confirmed` flag. `.confirm(ids)` bulk-confirms them for payroll. `modifiable_by?` lets admins edit anything, while other users can edit only their own unconfirmed records.
- A `Consultation` can be associated with at most one `FliipService` (enforced by a uniqueness check), within a window of −14 days to +3 months around `occurred_at`.

### Authorization
There is no policy gem. Each controller has its own `before_action` guard (`ensure_admin!`, `require_manager_only!`, `ensure_management!`, `authorize_role_changes!`) plus model predicates (`modifiable_by?`, `editable_by?`). After login, `ApplicationController#after_sign_in_path_for` and `RootController#redirect` route users by role: admins go to `/admin/dashboard`, managers to `/manager/dashboard`, and employees to their profile. `ManagerController` deliberately sends admins back to the admin dashboard.

### Filtering, search and CSV
- Admin list filters go through each model's `apply_filters(params)`, which chains scopes. Search uses accent-insensitive `pg_search_scope`s.
- `app/services/csv_porter/` handles CSV export of client services and the adjustments import. The import is a three-step flow: `adjustments_new` → `adjustments_preview` (dry run) → `adjustments_commit`. CSV dates use `dd/mm/yyyy`.

### Frontend
Interactivity uses Stimulus controllers in `app/javascript/controllers/` together with server-rendered partials. Inline table editing fetches member `row` routes (for example `GET /sessions/:id/row`) to swap rows. Mapbox and flatpickr are pinned in `config/importmap.rb`.
