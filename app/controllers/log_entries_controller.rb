class LogEntriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_generated_app

  def index
    @log_entries = @generated_app.log_entries.order(created_at: :desc)
  end

  private

  def set_generated_app
    @generated_app = GeneratedApp.find(params[:generated_app_id])
  end
end
