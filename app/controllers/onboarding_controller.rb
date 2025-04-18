class OnboardingController < ApplicationController
  before_action :authenticate_user!

  def update
    current_user.update!(onboarding_completed: true)
    redirect_to dashboard_path, notice: "Welcome to railsnew.io! You can always start the onboarding later from your dashboard."
  end
end
