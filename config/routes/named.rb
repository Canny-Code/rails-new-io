Rails.application.routes.draw do
  get "/github/check_name", to: "github#check_name", as: :check_github_name
end
