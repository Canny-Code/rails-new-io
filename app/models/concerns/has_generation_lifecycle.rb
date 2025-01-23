module HasGenerationLifecycle
  extend ActiveSupport::Concern

  included do
    has_many :app_changes, dependent: :destroy
    has_one :app_status, dependent: :destroy
    has_many :log_entries, class_name: "AppGeneration::LogEntry", dependent: :destroy

    after_create :create_app_status

    delegate :status, :status_history, :started_at, :completed_at, :error_message,
             :pending?, :generating?, :pushing_to_github?, :running_ci?, :completed?, :failed?,
             to: :app_status

    private

    def create_app_status
      build_app_status.save!
      logger.info("Starting app generation workflow")
    end

    def logger
      @logger ||= AppGeneration::Logger.new(self)
    end
  end

  def generate!
    puts "DEBUG: generate! called, current status: #{app_status.status}"
    touch(:last_build_at)
    app_status.start_generation!
    logger.info("Starting app generation")
  end

  def create_github_repo!
    puts "DEBUG: create_github_repo! called, current status: #{app_status.status}"
    touch(:last_build_at)
    app_status.start_github_repo_creation!
    logger.info("Starting GitHub repo creation")
  end

  def push_to_github!
    puts "DEBUG: push_to_github! called, current status: #{app_status.status}"
    app_status.start_github_push!
  end

  def start_ci!
    puts "DEBUG: start_ci! called, current status: #{app_status.status}"
    touch(:last_build_at)
    app_status.start_ci!
    logger.info("Starting CI run")
  end

  def mark_as_completed!
    puts "DEBUG: mark_as_completed! called, current status: #{app_status.status}"
    touch(:last_build_at)
    app_status.complete!
    logger.info("App generation completed successfully")
  end

  def mark_as_failed!(error_message)
    puts "DEBUG: mark_as_failed! called, current status: #{app_status.status}, error: #{error_message}"
    touch(:last_build_at)
    app_status.fail!(error_message)
    logger.error("App generation failed: #{error_message}")
  end

  def restart!
    puts "DEBUG: restart! called, current status: #{app_status.status}"
    touch(:last_build_at)
    app_status.restart!
    logger.info("Restarting app generation")
  end
end
