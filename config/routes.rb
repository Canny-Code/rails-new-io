Rails.application.routes.draw do
  draw :rails
  draw :authentication
  draw :static
  draw :root
  draw :admin
  draw :business_logic
  draw :named
end
