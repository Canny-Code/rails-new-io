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
    extend CoverageHelper

    parallelize(workers: :number_of_processors)

    unless skip_coverage?
      parallelize_setup do |worker|
        SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}"
      end

      parallelize_teardown do |_|
        SimpleCov.result
      end
    end

    fixtures :all
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

def silence_omniauth_logger
  original_logger = OmniAuth.config.logger
  OmniAuth.config.logger = Logger.new("/dev/null")
  yield
ensure
  OmniAuth.config.logger = original_logger
end
