unless ENV["SKIP_COVERAGE"] == "1"
  require "simplecov"

  SimpleCov.start do
    enable_coverage :branch

    add_filter "/config/"
    add_filter "/test/"

    add_group "Models", "app/models"
    add_group "Controllers", "app/controllers"
    add_group "Helpers", "app/helpers"
    add_group "Jobs", "app/jobs"
    add_group "Mailers", "app/mailers"

    track_files "{app/models,app/controllers,app/helpers}/**/*.rb"
  end
end

ENV["RAILS_ENV"] ||= "test"
# require "vite_rails" # let's see if we need this
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"


module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    unless ENV["SKIP_COVERAGE"] == "1"
      parallelize_setup do |worker|
        SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}"
      end

      parallelize_teardown do |_|
        SimpleCov.result
      end
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
