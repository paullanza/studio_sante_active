Rails.application.routes.draw do
  # =====================================================================
  # AUTHENTICATION (PUBLIC)
  # ---------------------------------------------------------------------
  # Devise provides sign up / sign in / password flows. All Devise paths
  # are public. Authorization is handled in controllers/policies.
  # =====================================================================
  # No email reset flow (the app sends no email): « Mot de passe oublié? »
  # explains who can reset a password instead. Registrations keep only
  # sign-up (below): accounts are deactivated, never deleted, and profiles
  # are edited through UsersController.
  devise_for :users, skip: [ :passwords, :registrations ]

  # Background jobs dashboard, for admins and above (MissionControlBaseController).
  mount MissionControl::Jobs::Engine, at: "/jobs"

  # Public landing page for users who are NOT authenticated. This points
  # to Devise's login form and becomes the site root for guests.
  devise_scope :user do
    unauthenticated do
      root to: "devise/sessions#new", as: :unauthenticated_root
    end

    get "mot-de-passe-oublie", to: "password_help#show", as: :password_help

    get "users/sign_up", to: "devise/registrations#new", as: :new_user_registration
    post "users", to: "devise/registrations#create", as: :user_registration
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
  # ADMIN — DASHBOARD
  # =====================================================================
  get "admin/dashboard", to: "admin#dashboard", as: :admin_dashboard

  # =====================================================================
  # ALLOCATIONS — SÉANCES AND ABSENCES ALLOWED PER KIND OF SERVICE
  # ---------------------------------------------------------------------
  # ServiceDefinition records, admins only. Rows are edited in place.
  # =====================================================================
  resources :allocations, only: [:index, :show, :update]

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
  # MANAGER VIEWS (READ-ONLY/REDUCED POWERS VS. ADMIN)
  # ---------------------------------------------------------------------
  # Manager dashboard for day-to-day oversight without admin-level
  # mutation rights. Managers can also create signup codes.
  # =====================================================================
  get  "manager/dashboard",     to: "manager#dashboard",    as: :manager_dashboard
  post "manager/signup_codes",  to: "manager#create_signup_code", as: :manager_signup_codes

  # =====================================================================
  # OVERSIGHT — FOLLOW-UP PAGES FOR MANAGERS AND ABOVE (« Plus » menu)
  # ---------------------------------------------------------------------
  # Échéances: services ending soon or ended recently, for renewals.
  # =====================================================================
  get "echeances", to: "oversight#echeances", as: :echeances

  # =====================================================================
  # MON PROFIL — THE SIGNED-IN USER'S OWN DETAILS AND PASSWORD
  # ---------------------------------------------------------------------
  # Always the current user, so there is no id in the URL.
  # =====================================================================
  resource :profile, only: [:show, :update], path: "profil" do
    patch :password, on: :member, action: :update_password
  end

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
  resources :sessions, only: [:create, :destroy, :edit, :update] do
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
  # Create/Destroy/Edit/Update for consultation records (the form lives on
  # the booking page, seances/new?tab=consultation). Member
  # routes support table row rendering (`row`), association UI (`association`),
  # and persisting the selected association (`associate`). `service_select`
  # offers a picker for linking to a client service.
  # =====================================================================
  resources :consultations, only: [:create, :destroy, :edit, :update] do
    member do
      get  :row
      get  :association
      patch :associate
      patch :disassociate
      get :service_select
    end

    collection do
      get :associations
    end
  end

  # =====================================================================
  # BOOKINGS — ALIAS FOR SÉANCES ENTRY POINT
  # ---------------------------------------------------------------------
  # Public-facing path used in the app to open the booking form for a
  # new "séance" (maps to Bookings controller).
  # =====================================================================
  get "seances/new", to: "bookings#new", as: :new_seance

  # Mes services: the services the signed-in staff member works on.
  get "mes-services", to: "my_services#index", as: :my_services

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
