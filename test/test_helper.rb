require_relative "support/coverage_helper"
extend CoverageHelper

unless skip_coverage?
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

    track_files "{app/models,app/controllers,app/helpers,app/jobs}/**/*.rb"
  end
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"
require "minitest/mock"
require "database_cleaner/active_record"
require "phlex/testing/view_helper"
require_relative "support/vite_test_helper"
require_relative "support/directory_test_helper"

# Ensure Vite's test environment is properly set
ENV["VITE_RUBY_TEST"] = "true"

class ActionDispatch::IntegrationTest
  include ViteTestHelper
  include DirectoryTestHelper
end

class ActionDispatch::SystemTest
  include ViteTestHelper
end

ActiveRecord::Encryption.configure(
  primary_key: "test" * 4,
  deterministic_key: "test" * 4,
  key_derivation_salt: "test" * 4
)

DatabaseCleaner.strategy = :transaction

module ActiveSupport
  class TestCase
    extend CoverageHelper

    # Only parallelize tests that don't do git operations
    parallelize(workers: :number_of_processors) unless ENV["TEST_DISABLE_PARALLEL"]

    unless skip_coverage?
      parallelize_setup do |worker|
        SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}"
      end

      parallelize_teardown do |_|
        SimpleCov.result
      end
    end

    fixtures :all

    def setup
      DatabaseCleaner.start

      %w[blog_app api_project saas_starter weather_api payment_api].each do |app|
        FileUtils.mkdir_p(Rails.root.join("tmp", "test_apps", app))
      end
    end

    def teardown
      DatabaseCleaner.clean
    end

    set_fixture_class noticed_notifications: AppStatusChangeNotifier::Notification
    set_fixture_class noticed_events: AppStatusChangeNotifier

    include DirectoryTestHelper
  end
end

# Add a module to mark tests that can't run in parallel
module DisableParallelization
  def self.included(base)
    base.class_eval do
      def self.inherited(klass)
        super
        klass.parallelize(workers: 1)
      end
    end
  end
end

def sign_in(user)
  OmniAuth.config.test_mode = true
  OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
    provider: user.provider,
    uid: user.uid,
    info: {
      email: user.email
    }
  )
  Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:github]
  Current.user = user
  post "/auth/github"
  follow_redirect!
end

# random github user
def login_with_github
  OmniAuth.config.test_mode = true
  OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(Faker::Omniauth.github)
  Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:github]
  post "/auth/github"
  follow_redirect!
end

def sign_out(_user)
  OmniAuth.config.mock_auth[:github] = nil
  Rails.application.env_config["omniauth.auth"] = nil
  Current.user = nil
  delete "/sign_out"
  follow_redirect!
end

def silence_omniauth_logger
  original_logger = OmniAuth.config.logger
  OmniAuth.config.logger = Logger.new("/dev/null")
  yield
ensure
  OmniAuth.config.logger = original_logger
end

module ActiveRecord
  class FixtureSet
    class << self
      def create_fixtures_with_order(fixtures_directory, fixture_set_names, class_names = {}, config = ActiveRecord::Base)
        # Define dependencies based on foreign keys
        dependencies = {
          "app_changes" => [ "ingredients", "generated_apps" ],
          "app_statuses" => [ "generated_apps" ],
          "recipe_ingredients" => [ "recipes", "ingredients" ],
          "generated_apps" => [ "recipes", "users" ],
          "recipes" => [ "users" ],
          "ingredients" => [ "users", "recipes" ],
          "commits" => [ "users" ]
        }

        # Load fixtures in correct order
        ordered_fixtures = []

        # First load users (no dependencies)
        ordered_fixtures << "users" if fixture_set_names.include?("users")

        # Then load models that depend on users
        %w[recipes ingredients commits].each do |model|
          ordered_fixtures << model if fixture_set_names.include?(model)
        end

        # Then load recipe_ingredients (depends on recipes and ingredients)
        ordered_fixtures << "recipe_ingredients" if fixture_set_names.include?("recipe_ingredients")

        # Then load generated_apps (depends on recipes and users)
        ordered_fixtures << "generated_apps" if fixture_set_names.include?("generated_apps")

        # Finally load models that depend on generated_apps
        %w[app_statuses app_changes].each do |model|
          ordered_fixtures << model if fixture_set_names.include?(model)
        end

        # Add any remaining fixtures
        remaining = fixture_set_names - ordered_fixtures
        ordered_fixtures.concat(remaining)

        # Sort fixture_set_names based on ordered_fixtures
        sorted_names = fixture_set_names.sort_by do |name|
          ordered_fixtures.index(name) || Float::INFINITY
        end

        create_fixtures_without_order(fixtures_directory, sorted_names, class_names, config)
      end

      alias_method :create_fixtures_without_order, :create_fixtures
      alias_method :create_fixtures, :create_fixtures_with_order
    end
  end
end

def assert_broadcasts_to(stream_name)
  broadcasts = []
  ActiveSupport::Notifications.subscribe("broadcast.action_cable") do |*args|
    event = args.last
    broadcasts << event
  end

  yield

  assert broadcasts.any? { |b|
    b[:streams]&.include?(stream_name) ||
    b[:stream] == stream_name ||
    b[:broadcasting] == stream_name
  }, "Expected broadcast to #{stream_name}, but none received"
ensure
  ActiveSupport::Notifications.unsubscribe("broadcast.action_cable")
end
