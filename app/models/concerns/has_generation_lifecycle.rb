module HasGenerationLifecycle
  extend ActiveSupport::Concern

  included do
    has_one :app_status, dependent: :destroy
    has_many :log_entries, class_name: "AppGeneration::LogEntry", dependent: :destroy

    after_create :create_app_status

    delegate :status, :status_history, :started_at, :completed_at, :error_message,
             :pending?, :generating?, :pushing_to_github?, :running_ci?, :completed?, :failed?,
             to: :app_status

    private

    def create_app_status
      build_app_status.save!
    end

    def logger
      @logger ||= AppGeneration::Logger.new(self)
    end
  end

  def generate!
    touch(:last_build_at)
    app_status.start_generation!
    logger.info("Starting app generation")
  end

  def push_to_github!
    touch(:last_build_at)
    app_status.start_github_push!
    logger.info("Starting GitHub push")
  end

  def start_ci!
    touch(:last_build_at)
    app_status.start_ci!
    logger.info("Starting CI run")
  end

  def mark_as_completed!
    touch(:last_build_at)
    app_status.complete!
    logger.info("App generation completed successfully 🎉")
  end

  def mark_as_failed!(error_message)
    touch(:last_build_at)
    app_status.fail!(error_message)
    logger.error("App generation failed: #{error_message}")
  end

  def restart!
    touch(:last_build_at)
    app_status.restart!
    logger.info("Restarting app generation")
  end
end
