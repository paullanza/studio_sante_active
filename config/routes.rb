Rails.application.routes.draw do
  # =====================================================================
  # AUTHENTICATION (PUBLIC)
  # ---------------------------------------------------------------------
  # Devise provides sign up / sign in / password flows. All Devise paths
  # are public. Authorization is handled in controllers/policies.
  # =====================================================================
  devise_for :users

  # Public landing page for users who are NOT authenticated. This points
  # to Devise's login form and becomes the site root for guests.
  devise_scope :user do
    unauthenticated do
      root to: "devise/sessions#new", as: :unauthenticated_root
    end
  end

  # =====================================================================
  # AUTHENTICATED AREA (PRIVATE)
  # ---------------------------------------------------------------------
  # Once logged in, users hit the internal redirect action which sends
  # them to the appropriate dashboard based on their role.
  # =====================================================================
  authenticated :user do
    root to: "root#redirect", as: :authenticated_root
  end

  # =====================================================================
  # CLIENTS (FLIIP USERS) — READ & SUGGESTIONS
  # ---------------------------------------------------------------------
  # Index/Show for client lookup and detail pages. `suggest` serves a
  # lightweight search endpoint (e.g., for the session creation page).
  # Refresh below pulls a fresh copy of a single Fliip user by remote_id.
  # =====================================================================
  resources :fliip_users, only: [:index, :show] do
    collection do
      get :suggest
    end
  end

  # Manually refresh a single Fliip user from the upstream API by
  # remote_id. Use when data is stale or after upstream changes.
  post "fliip_users/:remote_id/refresh", to: "fliip_users#refresh", as: :refresh_fliip_user

  # =====================================================================
  # ADMIN — DASHBOARD, SERVICE OVERSIGHT & EXPORTS
  # ---------------------------------------------------------------------
  # High-level admin views over services plus a CSV export for auditing
  # or payroll. `service_show` is an admin lens over a service; PATCH
  # allows inline updates by admins.
  # =====================================================================
  get   "admin/dashboard",        to: "admin#dashboard",        as: :admin_dashboard
  get   "admin/services",         to: "admin#services",         as: :admin_services
  get   "admin/services/:id",     to: "admin#service_show",     as: :admin_service
  patch "admin/services/:id",     to: "admin#update_service",   as: :update_admin_service
  get   "admin/client_services",  to: "admin#client_services",  defaults: { format: :csv }

  # =====================================================================
  # ADMIN — SIGNUP CODES (ACCESS CONTROL FOR NEW EMPLOYEES)
  # ---------------------------------------------------------------------
  # Create new codes and deactivate existing ones. Codes gate employee
  # self-sign-ups and typically expire after a set time.
  # =====================================================================
  post  "admin/signup_codes",                 to: "admin#create_signup_code",     as: :admin_signup_codes
  patch "admin/signup_codes/:id/deactivate",  to: "admin#deactivate_signup_code", as: :deactivate_admin_signup_code

  # =====================================================================
  # ADMIN — SESSION CONFIRMATION WORKFLOW
  # ---------------------------------------------------------------------
  # Used during payroll cycles: list unconfirmed sessions and perform a
  # bulk confirmation action across selected records.
  # =====================================================================
  get   "admin/unconfirmed_sessions", to: "admin#unconfirmed_sessions", as: :admin_unconfirmed_sessions
  patch "admin/confirm_sessions",     to: "admin#confirm_sessions",     as: :admin_confirm_sessions

  # =====================================================================
  # ADMIN — CONSULTATION CONFIRMATION WORKFLOW
  # ---------------------------------------------------------------------
  # Used during payroll cycles: list unconfirmed consultations and
  # perform a bulk confirmation action across selected records.
  # =====================================================================
  get   "admin/unconfirmed_consultations", to: "admin#unconfirmed_consultations", as: :admin_unconfirmed_consultations
  patch "admin/confirm_consultations",     to: "admin#confirm_consultations",     as: :admin_confirm_consultations

  # =====================================================================
  # ADMIN — SERVICE USAGE ADJUSTMENTS (BULK TOOLS)
  # ---------------------------------------------------------------------
  # 1) `adjustments_new`: start a new adjustment run
  # 2) `adjustments_preview`: dry-run to review computed changes
  # 3) `adjustments_commit`: apply adjustments to usage counters
  # =====================================================================
  get  "admin/adjustments/new",     to: "admin#adjustments_new",     as: :admin_adjustments_new
  post "admin/adjustments/preview", to: "admin#adjustments_preview", as: :admin_adjustments_preview
  post "admin/adjustments/commit",  to: "admin#adjustments_commit",  as: :admin_adjustments_commit

  # =====================================================================
  # MANAGER VIEWS (READ-ONLY/REDUCED POWERS VS. ADMIN)
  # ---------------------------------------------------------------------
  # Manager dashboard and service views for day-to-day oversight without
  # admin-level mutation rights. Managers can also create signup codes.
  # =====================================================================
  get  "manager/dashboard",     to: "manager#dashboard",    as: :manager_dashboard
  get  "manager/services",      to: "manager#services",     as: :manager_services
  get  "manager/services/:id",  to: "manager#service_show", as: :manager_service
  post "manager/signup_codes",  to: "manager#create_signup_code", as: :manager_signup_codes

  # =====================================================================
  # USERS — PROFILE & ROLE MANAGEMENT
  # ---------------------------------------------------------------------
  # Show/update the user profile, plus role/activation toggles gated by
  # authorization. Role setters promote/demote a user to the given role.
  # =====================================================================
  resources :users, only: [:show, :edit, :update] do
    member do
      patch :make_employee
      patch :make_manager
      patch :make_admin
      patch :activate
      patch :deactivate
    end
  end

  # =====================================================================
  # SESSIONS — BOOKING / CREATION FLOW
  # ---------------------------------------------------------------------
  # New/Create/Destroy/Edit/Update for session records. Member `row`
  # renders a partial for dynamic table updates. Collection helpers power
  # the booking UI: `services_table` renders a table partial; `service_select`
  # is the step to choose a client service before creating a session.
  # `preview_type` supports client-side previews of session types.
  # =====================================================================
  resources :sessions, only: [:new, :create, :destroy, :edit, :update] do
    member do
      get :row
    end

    collection do
      get :services_table
      get :service_select
    end
  end

  get "sessions/preview_type", to: "sessions#preview_type"

  # =====================================================================
  # CONSULTATIONS — CREATION & ASSOCIATION FLOW
  # ---------------------------------------------------------------------
  # New/Create/Destroy/Edit/Update for consultation records. Member
  # routes support table row rendering (`row`), association UI (`association`),
  # and persisting the selected association (`associate`). `service_select`
  # offers a picker for linking to a client service.
  # =====================================================================
  resources :consultations, only: [:new, :create, :destroy, :edit, :update] do
    member do
      get  :row
      get  :association
      patch :associate
      patch :disassociate
      get  :service_select
    end
  end

  # =====================================================================
  # BOOKINGS — ALIAS FOR SÉANCES ENTRY POINT
  # ---------------------------------------------------------------------
  # Public-facing path used in the app to open the booking form for a
  # new "séance" (maps to Bookings controller).
  # =====================================================================
  get "seances/new", to: "bookings#new", as: :new_seance

  # =====================================================================
  # ASYNC HELPERS — BOOKING/IMPORT FLOWS
  # ---------------------------------------------------------------------
  # - refresh_clients: refresh client list for the booking form
  # - import_clients: one-off import invoked from admin
  # =====================================================================
  post "refresh_clients", to: "sessions#refresh_clients", as: :refresh_clients
  post "import_clients",  to: "admin#import_clients",     as: :import_clients

  # =====================================================================
  # FLIIP SERVICES — DETAIL VIEW & AD-HOC ADJUSTMENTS
  # ---------------------------------------------------------------------
  # Show a single Fliip service. Nested routes manage adjustments that
  # tweak usage counts for that specific service.
  # =====================================================================
  resources :fliip_services, only: [:show] do
    resources :service_usage_adjustments, only: [:create, :edit, :update, :destroy]
  end

  # =====================================================================
  # HEALTHCHECK (PUBLIC)
  # ---------------------------------------------------------------------
  # Minimal endpoint used by uptime monitors or container orchestrators.
  # Does not disclose sensitive information.
  # =====================================================================
  get "up" => "rails/health#show", as: :rails_health_check
end
