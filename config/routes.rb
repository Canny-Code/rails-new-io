Rails.application.routes.draw do
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

  root to: "static#home"
end
