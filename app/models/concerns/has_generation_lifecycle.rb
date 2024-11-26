module HasGenerationLifecycle
  extend ActiveSupport::Concern

  included do
    has_one :app_status, dependent: :destroy
    after_create :create_app_status

    delegate :status, :status_history, :started_at, :completed_at, :error_message,
             :pending?, :generating?, :pushing_to_github?, :running_ci?, :completed?, :failed?,
             to: :app_status

    private

    def create_app_status
      build_app_status.save!
    end
  end

  def generate!
    touch(:last_build_at)
    app_status.start_generation!
  end

  def push_to_github!
    touch(:last_build_at)
    app_status.start_github_push!
  end

  def start_ci!
    touch(:last_build_at)
    app_status.start_ci!
  end

  def mark_as_completed!
    touch(:last_build_at)
    app_status.complete!
  end

  def mark_as_failed!(error_message)
    touch(:last_build_at)
    app_status.fail!(error_message)
  end

  def restart!
    touch(:last_build_at)
    app_status.restart!
  end
end
