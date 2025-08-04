Rails.application.routes.draw do
  # Root path
  root "fliip_users#index"

  # Devise authentication
  devise_for :users

  # Public routes
  resources :fliip_users, only: [:show]
  post "fliip_users/:remote_id/refresh", to: "fliip_users#refresh", as: :refresh_fliip_user


  # Admin dashboard and features (flat controller)
  get   "admin/dashboard",                to: "admin#dashboard",              as: :admin_dashboard

  # Service session definitions
  get   "admin/services",                 to: "admin#services",               as: :admin_services
  patch "admin/services/:id",            to: "admin#update_service",         as: :update_admin_service

  # Signup codes
  post  "admin/signup_codes",            to: "admin#create_signup_code",     as: :admin_signup_codes
  patch "admin/signup_codes/:id/deactivate", to: "admin#deactivate_signup_code", as: :deactivate_admin_signup_code

  # Confirmation of sessions routes
  get  "admin/unconfirmed_sessions", to: "admin#unconfirmed_sessions", as: :admin_unconfirmed_sessions
  patch "admin/confirm_sessions",     to: "admin#confirm_sessions",     as: :admin_confirm_sessions


  # User profiles and admin/mod actions
  resources :users, only: [:show] do
    member do
      patch :toggle_role
      patch :activate
      patch :deactivate
    end
  end

  resources :sessions, only: [:new, :create]

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
