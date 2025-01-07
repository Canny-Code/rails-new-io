Rails.application.routes.draw do
  get "pages/show"
  get "up", to: "rails/health#show", as: :rails_health_check

  mount MissionControl::Jobs::Engine, at: "/jobs"

  get "service-worker", to: "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest", to: "rails/pwa#manifest", as: :pwa_manifest

  scope controller: :static do
    get :home
    get :why
    get :"live-demo"
    get :about
  end

  get "auth/github/callback", to: "sessions#create"
  get "auth/failure", to: "sessions#failure"
  delete "sign_out", to: "sessions#destroy"

  get "dashboard", to: "dashboard#show"

  resources :notifications, only: [ :index, :update ]

  resources :generated_apps, only: [ :show, :create ] do
    resources :generation_attempts, only: [ :create ]
    resources :log_entries, only: [ :index ]
  end

  resources :ingredients

  resources :users, only: [ :show ], path: ""

  resources :pages, only: :show

  constraints lambda { |request| request.session[:user_id].present? } do
    root to: "dashboard#show", as: :authenticated_root
  end

  root to: "static#home"

  # named routes
  get "/github/check_name", to: "github#check_name", as: :check_github_name
end
