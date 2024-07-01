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
    config.application_name = "railsnew.io"

    config.load_defaults 7.2

    config.autoload_lib(ignore: %w[assets tasks])
  end
end
