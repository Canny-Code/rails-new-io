Rails.application.routes.draw do
  scope controller: :static do
    get :home
    get :why
    get :"live-demo"
    get :about
  end
end
