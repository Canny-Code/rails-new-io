Rails.application.routes.draw do
  get "dashboard", to: "dashboard#show"

  constraints(->(request) { request.session[:user_id].present? }) do
    root to: "dashboard#show", as: :authenticated_root
  end

  root to: "static#home"
end
