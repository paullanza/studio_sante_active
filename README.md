# Studio Santé Active — Rails App

This Rails application powers the internal operations of **Studio Santé Active**, integrating with the upstream **Fliip API** to sync clients and services, and providing tools for employees, managers, and admins to manage sessions, adjustments, and payroll.

---

## Features

* **Authentication**: Devise handles user signup/login.

  * Signup is restricted via manager/admin–generated codes.
  * Roles: `employee`, `manager`, `admin`.
* **Client & Service Sync**:

  * Local database mirrors clients (`FliipUser`) and services (`FliipService`) from the Fliip API.
  * `FliipContract` records provide additional membership details.
* **Sessions**:

  * Employees create session records tied to a client + service.
  * Tracks attendance, notes, presence/absence, and confirmation status.
  * Admin bulk confirmation workflow supports payroll.
* **Adjustments**:

  * Service usage adjustments allow manual corrections (paid/free/bonus sessions).
  * Adjustments are auditable (tied to the user who created them).
* **Admin Tools**:

  * Dashboards, service oversight, CSV exports.
  * Session confirmation and adjustment bulk tools.
* **Manager Tools**:

  * Read-only dashboards for day-to-day oversight.
* **User Profiles**:

  * Employees can view their own created sessions and adjustments.

---

## Tech Stack

* **Ruby** 3.3.5
* **Ruby on Rails** 7.1.5.1
* **PostgreSQL** with `plpgsql` and `unaccent` extensions
* **Devise** for authentication
* **Pundit** for authorization
* **Stimulus** for lightweight JavaScript interactions
* **Bootstrap 5** (forms only, no full-site styling)

---

## Dependencies

### Core Gems

* **pg** (\~> 1.1) — PostgreSQL adapter
* **importmap-rails** (\~> 1.2.3) — JavaScript imports
* **turbo-rails** — Hotwire Turbo
* **stimulus-rails** — Hotwire Stimulus
* **jbuilder** — JSON API builder

### Authentication / Authorization

* **devise** — User authentication

### Background Jobs

* **solid\_queue** — Background job processing

### API & Utilities

* **httparty** — API calls to Fliip
* **dotenv-rails** — Environment variable management
* **ostruct** — OpenStruct helper

### Search & Geocoding

* **pg\_search** — Advanced PostgreSQL full-text search
* **geocoder** — Geocoding client addresses

### Forms, CSS, UI

* **simple\_form** — Easier form builders
* **bootstrap** (\~> 5.3.3) — UI framework (forms only)
* **sassc-rails** — SCSS compilation

### Pagination

* **pagy** — Simple, fast paginationr

## Data Model (simplified)

* **User**: Employees, managers, admins.
* **SignupCode**: Grants access to new employees.
* **FliipUser**: A client record (from upstream).
* **FliipService**: A purchased service for a client.
* **FliipContract**: Membership/contract details.
* **ServiceDefinition**: Local catalog of service capacities.
* **Session**: Attendance record tied to a client + service.
* **ServiceUsageAdjustment**: Manual usage correction.

---

## License

Private application for **Studio Santé Active**. Not open for external distribution.
