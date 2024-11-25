class GenerationAttemptsController < ApplicationController
  before_action :authenticate_user!

  def create
    console
    @generated_app = GeneratedApp.find(params[:generated_app_id])

    if @generated_app.status == "failed"
      @generated_app.app_status.restart!
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to dashboard_path }
    end
  end
end
