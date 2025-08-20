Rails.application.routes.draw do
  # -----------------------------------------
  # Devise authentication routes (PUBLIC)
  # -----------------------------------------
  devise_for :users

  # Public root for visitors who are NOT signed in
  devise_scope :user do
    unauthenticated do
      root to: "devise/sessions#new", as: :unauthenticated_root
    end
  end

  # -----------------------------------------
  # All remaining routes are PRIVATE
  # -----------------------------------------
  # Authenticated root: dashboard (private)
  authenticated :user do
    root to: "admin#dashboard", as: :authenticated_root
  end

  # -----------------------------------------
  # Client & Service management
  # -----------------------------------------
  resources :fliip_users, only: [:index, :show] do
    collection do
      get :suggest
    end
  end

  post "fliip_users/:remote_id/refresh", to: "fliip_users#refresh", as: :refresh_fliip_user

  # -----------------------------------------
  # Admin dashboard & services
  # -----------------------------------------
  get   "admin/dashboard",  to: "admin#dashboard",      as: :admin_dashboard
  get   "admin/services",   to: "admin#services",       as: :admin_services
  get   "admin/services/:id", to: "admin#service_show", as: :admin_service
  patch "admin/services/:id", to: "admin#update_service", as: :update_admin_service
  get   "admin/client_services", to: "admin#client_services", defaults: { format: :csv }

  # -----------------------------------------
  # Signup codes
  # -----------------------------------------
  post  "admin/signup_codes", to: "admin#create_signup_code", as: :admin_signup_codes
  patch "admin/signup_codes/:id/deactivate", to: "admin#deactivate_signup_code", as: :deactivate_admin_signup_code

  # -----------------------------------------
  # Session confirmation
  # -----------------------------------------
  get   "admin/unconfirmed_sessions", to: "admin#unconfirmed_sessions", as: :admin_unconfirmed_sessions
  patch "admin/confirm_sessions",     to: "admin#confirm_sessions",     as: :admin_confirm_sessions

  # -----------------------------------------
  # Service usage adjustments
  # -----------------------------------------
  get  "admin/adjustments/new",     to: "admin#adjustments_new",     as: :admin_adjustments_new
  post "admin/adjustments/preview", to: "admin#adjustments_preview", as: :admin_adjustments_preview
  post "admin/adjustments/commit",  to: "admin#adjustments_commit",  as: :admin_adjustments_commit

  # -----------------------------------------
  # User profile & role management
  # -----------------------------------------
  resources :users, only: [:show, :update] do
    member do
      patch :make_employee
      patch :make_manager
      patch :make_admin
      patch :activate
      patch :deactivate
    end
  end

  # -----------------------------------------
  # Session creation / booking
  # -----------------------------------------
  resources :sessions, only: [:new, :create, :show, :edit, :update, :destroy] do
    collection do
      get :services_table
      get :service_select
    end
  end

  post "refresh_clients", to: "sessions#refresh_clients", as: :refresh_clients
  post "import_clients",  to: "admin#import_clients",     as: :import_clients

  # -----------------------------------------
  # Fliip service details
  # -----------------------------------------
  resources :fliip_services, only: [:show] do
    resources :service_usage_adjustments, only: [:create, :edit, :update, :destroy]
  end

  # -----------------------------------------
  # Health check (PUBLIC, typically safe)
  # -----------------------------------------
  get "up" => "rails/health#show", as: :rails_health_check
end
