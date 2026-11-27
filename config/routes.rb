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
  # ServiceDefinition records, admins only. PATCH /allocations saves a batch:
  # the « à définir » queue, or the corrections made in « Mode correction ».
  # =====================================================================
  resources :allocations, only: [:index, :show]
  patch "allocations", to: "allocations#bulk_update", as: :bulk_update_allocations

  # =====================================================================
  # CODES D'INSCRIPTION (managers and above)
  # ---------------------------------------------------------------------
  # A code lets a new hire sign up: it lasts 14 days and works once.
  # =====================================================================
  resources :signup_codes, only: [:index, :create], path: "codes-inscription" do
    patch :deactivate, on: :member
  end

  # =====================================================================
  # CONFIRMATIONS (admins, before payroll)
  # ---------------------------------------------------------------------
  # A pay period's unconfirmed séances or consultations: confirm them in bulk.
  # =====================================================================
  get   "confirmations/seances",       to: "confirmations#sessions",              as: :session_confirmations
  patch "confirmations/seances",       to: "confirmations#confirm_sessions",      as: :confirm_session_confirmations
  get   "confirmations/consultations", to: "confirmations#consultations",         as: :consultation_confirmations
  patch "confirmations/consultations", to: "confirmations#confirm_consultations", as: :confirm_consultation_confirmations

  # =====================================================================
  # MANAGER VIEWS (READ-ONLY/REDUCED POWERS VS. ADMIN)
  # ---------------------------------------------------------------------
  # Manager dashboard for day-to-day oversight without admin-level
  # mutation rights.
  # =====================================================================
  get "manager/dashboard", to: "manager#dashboard", as: :manager_dashboard

  # =====================================================================
  # OVERSIGHT — FOLLOW-UP PAGES FOR MANAGERS AND ABOVE (« Plus » menu)
  # ---------------------------------------------------------------------
  # Échéances: services ending soon or ended recently, for renewals.
  # Séances récentes: the latest séances across the studio.
  # =====================================================================
  get "echeances",        to: "oversight#echeances",       as: :echeances
  get "seances-recentes", to: "oversight#recent_sessions", as: :recent_sessions

  # =====================================================================
  # MON PROFIL — THE SIGNED-IN USER'S OWN DETAILS AND PASSWORD
  # ---------------------------------------------------------------------
  # Always the current user, so there is no id in the URL.
  # =====================================================================
  resource :profile, only: [:show, :update], path: "profil" do
    patch :password, on: :member, action: :update_password
  end

  # =====================================================================
  # PERSONNEL — THE STAFF LIST AND A PAGE PER STAFF MEMBER
  # ---------------------------------------------------------------------
  # /personnel (managers and above) and /personnel/:id, plus the old edit
  # page and the role and activation toggles, gated by UserPolicy.
  # =====================================================================
  resources :users, only: [:index, :show, :edit, :update], path: "personnel" do
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
  # Create/Destroy/Edit/Update for session records (the form lives on the
  # booking page, seances/new). Member `row` renders a partial for dynamic
  # table updates.
  # =====================================================================
  resources :sessions, only: [:create, :destroy, :edit, :update] do
    member do
      get :row
    end
  end

  # =====================================================================
  # CONSULTATIONS — CREATION & LINKING
  # ---------------------------------------------------------------------
  # Create/Destroy/Edit/Update for consultation records (the form lives on
  # the booking page, seances/new?tab=consultation). `row` gives a card or
  # an old table row back. `index` lists the recent consultations (managers
  # and above). « Lier les consultations » (`associations`) lists
  # those without a service; `association` opens the link form in a card,
  # `associate` saves the link and `disassociate` clears it.
  # =====================================================================
  resources :consultations, only: [:index, :create, :destroy, :edit, :update] do
    member do
      get  :row
      get  :association
      patch :associate
      patch :disassociate
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
    resources :service_usage_adjustments, only: [:show, :create, :edit, :update, :destroy]
  end

  # =====================================================================
  # HEALTHCHECK (PUBLIC)
  # ---------------------------------------------------------------------
  # Minimal endpoint used by uptime monitors or container orchestrators.
  # Does not disclose sensitive information.
  # =====================================================================
  get "up" => "rails/health#show", as: :rails_health_check
end
