class SessionsController < ApplicationController
  def create
    Rails.logger.info "OmniAuth Auth Hash: #{request.env['omniauth.auth'].inspect}"
    @user = User.create_from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      session[:user_id] = @user.id
      redirect_path = request.env["omniauth.origin"] || dashboard_path
      redirect_to redirect_path, notice: "Logged in as #{@user.name}"
    else
      redirect_to root_url, alert: "Failure"
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path, notice: "Logged out"
  end

  def failure
    Rails.logger.error "OmniAuth Failure: #{request.env['omniauth.error'].inspect}"
    Rails.logger.error "OmniAuth Error Type: #{request.env['omniauth.error.type'].inspect}"
    redirect_to root_path, alert: "Authentication failed"
  end
end
