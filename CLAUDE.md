# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Internal staff app for Studio Santé Active, a fitness/health studio. Employees log training sessions ("séances") and consultations against client services that are mirrored from the **Fliip** gym-management API. Admins confirm sessions and consultations for payroll and adjust service usage. UI copy and validation messages are in **French**. App time zone is `Eastern Time (US & Canada)`.

Stack: Rails 8.1, Ruby 3.4.9, PostgreSQL (needs the `unaccent` extension), Devise, Hotwire (Turbo + Stimulus via importmap, so there is no Node build step), Bootstrap 5 compiled by `dartsass-rails` and served by Propshaft, simple_form, pg_search, Pagy, Solid Queue. Deployed on Render with its native Ruby runtime, configured in the Render dashboard (there is no `render.yaml`): `bin/render-build.sh` runs migrations and seeds on every build, and a separate cron job runs `rake fliip:sync`.

Solo lead dev (Paul) owns all architecture and maintenance decisions. The app is in production, so production safety matters. Work happens in bursts after long quiet periods, so a snapshot of the code may be stale: read the current file before changing it.

---

## Working agreement

- Ask clarifying questions before complex work. When several approaches are valid, give options with tradeoffs instead of one answer.
- Explain the why behind a recommendation, briefly. Keep messages concise; if more is needed, Paul will ask.
- Flag anything that adds a dependency, adds significant complexity, or needs a large refactor before doing it.
- Prefer simple, maintainable solutions over clever ones.
- One fix or piece per step. Paul confirms each one works before moving to the next, so don't batch untested changes.
- Plan larger work in phases and list the files created or modified in each phase.
- Read the actual current file before changing it. Never assume a library is available; check the Gemfile.
- Verify the shape of data coming from the Fliip API or any external source. Never assume it.
- When diagnosing an error, ask for the server log or backtrace before proposing a fix. Don't guess from a bare error message or failing test line. Confirm whether the problem is in production or local first.
- Don't re-run the suite once tests are confirmed green.
- If something being done could cause a problem down the line, say so.

---

## Commands

```bash
bin/setup                       # install gems, prepare DB
bin/dev                         # dev server + Sass watcher (Procfile.dev); plain `bin/rails server` won't recompile CSS
bin/rails dartsass:build        # compile app/assets/stylesheets → app/assets/builds (gitignored; assets:precompile does this too)
bin/rails db:migrate
bundle exec rspec                                   # all specs
bundle exec rspec spec/models/session_spec.rb:12    # one example by line
bundle exec rubocop                                 # lint (rubocop-rails-omakase)
bundle exec brakeman -q                             # security scan
bundle exec bundle-audit check --update             # known-vulnerable gems
bin/rails fliip:sync            # full Fliip → local DB sync (lib/tasks/fliip_sync.rake)
```

`FLIIP_API_KEY` must be set (loaded from `.env` via dotenv-rails). `FliipApi::ApiClient` calls `ENV.fetch` on it and raises if it is missing.

Prefer Ruby scripts over bash for API experiments. Save their output files next to the script, not in `/tmp`, so they show up in VSCode.

---

## Architecture

### Two kinds of "users"
- `User`: staff accounts (Devise). `role` enum: `employee`, `manager`, `admin`, `super_admin`. Sign-up requires a valid `SignupCode` (8 characters, expiring, consumed on create). An `active` flag blocks login, and `ApplicationController#logout_if_inactive` signs out deactivated users on every request.
- `FliipUser`: read-only mirrors of Fliip records, keyed by `remote_id` (Fliip's id). They have many `FliipContract`s and `FliipService`s. Don't edit Fliip-owned fields locally, because the next sync overwrites them.
  - Clients and Fliip staff both live here. Staff carry a `user_role` other than `"user"`; use `staff?` (`user_role.present? && user_role != "user"`). There is no separate column for this.

### Naming collision: `Session`
`Session` is a domain model (a booked training session), not an HTTP session. `SessionsController` / `resources :sessions` are this model's CRUD and are separate from Devise's `devise/sessions` login controller. The booking form lives at `seances/new` (`BookingsController#new`).

### Fliip sync (`app/services/fliip_api/`)
- `ApiClient` is a thin HTTParty wrapper over `https://static.fliipapp.com/api/v2`. On failure it logs the error and returns `[]`, so an outage looks like "no data". Keep that in mind when a sync appears to do nothing.
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
There is currently no policy gem. Each controller has its own `before_action` guard (`ensure_admin!`, `require_manager_only!`, `ensure_management!`, `authorize_role_changes!`) plus model predicates (`modifiable_by?`, `editable_by?`). After login, `ApplicationController#after_sign_in_path_for` and `RootController#redirect` route users by role: admins go to `/admin/dashboard`, managers to `/manager/dashboard`, and employees to their profile. `ManagerController` deliberately sends admins back to the admin dashboard.

A migration to Pundit is planned (see Planned direction). Until then, don't add new ad hoc guard styles: reuse the existing guards, and write new authorization logic so it maps cleanly onto a policy later.

### Filtering, search and CSV
- Admin list filters go through each model's `apply_filters(params)`, which chains scopes. Search uses accent-insensitive `pg_search_scope`s.
- `app/services/csv_porter/` handles CSV export of client services and the adjustments import. The import is a three-step flow: `adjustments_new` → `adjustments_preview` (dry run) → `adjustments_commit`. CSV dates use `dd/mm/yyyy`.

### Frontend
Interactivity uses Stimulus controllers in `app/javascript/controllers/` together with server-rendered partials. Inline table editing fetches member `row` routes (for example `GET /sessions/:id/row`) to swap rows. JS packages are vendored into `vendor/javascript` and pinned in `config/importmap.rb` (`./bin/importmap pin <pkg>` downloads them; there are no CDN pins). Address autocomplete is the `<mapbox-search-box>` web component from `@mapbox/search-js-web`, created by `address_autocomplete_controller.js`; it writes the chosen address into the hidden `address` input. Clean up event listeners in `disconnect()` for Turbo compatibility.

Styles: Sass partials live in `app/assets/stylesheets/components/` and each must be listed with `@use` in `components/index.scss`. `dartsass-rails` compiles `application.scss` into `app/assets/builds/` (gitignored) and Propshaft serves it; the raw `.scss` files are excluded from publishing in `config/initializers/assets.rb`. The `bootstrap`, `@popperjs/core`, Turbo and Stimulus pins resolve from gem assets, not from `vendor/javascript`.

---

## Known gotchas

- **Nil-guard pattern.** Never write `@ivar = value if condition` with no `else` in a controller. It leaves the variable `nil` on non-happy paths and crashes the view (this caused the `@staff` error in `bookings/new`). The reference implementations are `BookingsController#load_staff` and `ConsultationsController#load_staff`, which use a ternary that defaults to `[]`. When touching a controller, check for this pattern.
- **Fliip API limit cap.** Very high `limit` values return `400 Bad Request` with an empty body. Use paginated requests (`limit=100` plus `offset`).
- **Silent logger crashes.** Non-UTF-8 characters in API responses once crashed the Rails logger silently and masked the real error. If logs go missing, suspect encoding before suspecting the logger config.
- **Render resources.** The web instance is small. Background jobs run in a separate Render cron job service, not in the web process. Keep heavy work (full syncs, large exports) out of web requests, and treat memory use as a design constraint.
- **Build side effects.** `bin/render-build.sh` runs migrations and seeds on every deploy, so seeds must be idempotent.
- **Vendored importmap pins can be silently broken.** `bin/importmap pin` downloads one file per package. It breaks if a file name contains `#` (Rails drops the pin and logs "Importmap skipped missing path") or if a file has relative imports like `from"./x.js"` (the sibling files aren't downloaded). Check both after pinning, and confirm in a real browser: specs can't catch it.

---

## Planned direction

Work is sequenced in phases. Bugs and stability come first, so don't start a later phase early without checking with Paul:

1. Bug fixes (nil-guard audit across controllers and views)
2. Test suite foundation
3. Gem and Rails upgrade (Rails 8, Propshaft replacing Sprockets)
4. Pundit authorization migration
5. Timesheet
6. Analytics and client map

---

## Code conventions

- Use `bin/rails generate` for new models, controllers, and services so migration, model, factory and spec are wired together. Don't hand-write these files from scratch.
- Keep UI copy and validation messages in French.
- Retired enum values get a commented-out line reserving the ordinal instead of silent deletion.
- JavaScript/Stimulus is out of scope for automated tests.

---

## Testing

RSpec, FactoryBot (`spec/factories/`), Shoulda Matchers and Faker, with config in `spec/support/`. Request specs sign in with Devise's `sign_in`. `spec/factories_spec.rb` lints every factory and trait. Bullet is enabled in development only. CI (`.github/workflows/ci.yml`) runs Brakeman, bundler-audit, `bin/importmap audit`, RuboCop and RSpec on every pull request, plus a production boot check (production gems only, assets compiled twice, then booted); specs run on Postgres 16 like production, and the dependency audits also run weekly; the existing RuboCop offenses are listed in `.rubocop_todo.yml`, so new code must be clean.

- The Fliip API is never called in specs: stub `FliipApi::ApiClient.new` with an `instance_double` (see `spec/services/fliip_api/user_sync/user_importer_spec.rb`).
- Build coverage in this order: models, then services, then controller/request specs.
- Every new file or class gets specs in the same pass. Controller changes and their request specs ship together.
- When adding to an existing spec file, add only the new block. Don't rewrite the whole file.
- Request specs shouldn't match on `response.body` unless there is no other way. Prefer flat `context` structures over deeply nested ones.
- `after_commit` callbacks don't fire in RSpec (transactions wrap specs and never truly commit). Test the private method directly via `send` instead.

---

## Schema changes

When a table is modified (field added, removed, or changed), check and update all of these in the same phase, without being asked:

- Factories
- Views and forms that render the changed fields
- Service objects that touch the table, including the Fliip sync and CSV porter
- Controllers, especially strong params
- Colspan values on empty-state rows and any other multi-column-spanning rows

Don't add editable local fields on top of Fliip-owned columns. Data migrations use local `Migration*` model classes scoped to the migration file, never live application models. Flag any migration that locks a large table or can't be rolled back before running it.

---

## Refactor safety

- Never blind find-and-replace a method call across the app. First check whether the same value is used as a comparison or lookup key (case statements, `where` clauses, enum matching). Those keep their exact original value; only true display usages change.
- Never suggest or start a change that needs significant refactoring without flagging the scope first. This matters most during the Rails 8 and Pundit work.

---

## Linear

Work is tracked in Linear.

- Issue creation requires the team to be set (it can fail silently without it).
- Status must reflect reality. When an issue's original scope is complete, close it immediately and open a new issue for follow-on work.
- Prefer one issue over several for small, tightly-related changes. Capture follow-up items as new issues.
- Issue descriptions are first person, concise but detailed, scoped as a single branch of work. Describe only what is done or what is left.
- `save_issue` with `parentId: None` clears parent/child links. `blockedBy` takes an array of issue IDs. State names work as literal strings. Project updates need the project ID, not the name.
- `save_project` 502 timeouts often succeed server-side. Verify with `get_project` before retrying.
