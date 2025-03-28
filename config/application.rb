require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
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

    config.autoload_lib(ignore: %w[assets tasks])

    # Litestream configuration
    litestream_credentials = Rails.application.credentials.litestream
    config.litestream.replica_bucket = litestream_credentials.replica_bucket rescue "test"
    config.litestream.replica_key_id = litestream_credentials.replica_key_id rescue "123"
    config.litestream.replica_access_key = litestream_credentials.replica_access_key rescue "456"
  end
end
