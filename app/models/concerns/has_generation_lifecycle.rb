module HasGenerationLifecycle
  extend ActiveSupport::Concern

  included do
    has_one :app_status, dependent: :destroy
    has_many :log_entries, class_name: "AppGeneration::LogEntry", dependent: :destroy

    after_create :create_app_status

    # Core attributes
    delegate :status, :status_history, :started_at, :completed_at, :error_message,
             *AppStatus.state_predicates,
             *AppStatus.events,
             to: :app_status

    after_update_commit :broadcast_clone_box, if: :completed?

    broadcasts_to ->(generated_app) { [ :generated_apps, generated_app.user_id ] }
    broadcasts_to ->(generated_app) { [ :notification_badge, generated_app.user_id ] }

    private

    def create_app_status
      build_app_status.save!
    end
  end
end
