require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module RailsNewIo
  class Application < Rails::Application
    config.autoload_paths.push(
      "#{root}/app/views/components",
      "#{root}/app/views",
      "#{root}/app/views/layouts"
    )

    config.application_name = "railsnew.io"

    config.load_defaults 8.0

    # Use Solid Queue for background jobs
    config.active_job.queue_adapter = :solid_queue
    config.solid_queue.connects_to = { database: { writing: :queue } }
    # Ensure authorization is enabled for the Solid Queue web UI
    config.mission_control.jobs.base_controller_class = "MissionControl::BaseController"

    config.autoload_lib(ignore: %w[assets tasks])
  end
end
