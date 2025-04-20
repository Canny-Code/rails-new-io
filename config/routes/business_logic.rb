Rails.application.routes.draw do
  resources :notifications, only: [ :index, :update ]

  resources :recipes, only: [ :index, :show, :create, :destroy, :update ] do
    collection do
      get "new/:slug", action: :new, controller: :pages, as: :setup
      get "edit/:recipe_id/:slug", action: :edit, controller: :pages, as: :edit
    end
  end

  resources :generated_apps, only: [ :new, :show, :create ] do
    resources :log_entries, only: [ :index ]
  end

  resources :ingredients
  resources :users, only: [ :show ], path: ""
  resource :onboarding, only: [ :update ]
end
