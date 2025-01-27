require "test_helper"

class AppDomainTest < ActiveSupport::TestCase
  def setup
    @original_host = ENV["APP_HOST"]
    @original_port = ENV["APP_PORT"]
    Rails.application.config.action_mailer.default_url_options = {}
    Rails.application.routes.default_url_options = {}
  end

  def teardown
    ENV["APP_HOST"] = @original_host
    ENV["APP_PORT"] = @original_port
    Rails.application.config.action_mailer.default_url_options = {}
    Rails.application.routes.default_url_options = {}
  end

  test "generates url with port when port is configured" do
    ENV["APP_HOST"] = "example.com"
    ENV["APP_PORT"] = "3000"

    assert_equal "http://example.com:3000", AppDomain.url
  end

  test "generates url without port when port is not configured" do
    ENV["APP_HOST"] = "example.com"
    ENV["APP_PORT"] = nil

    assert_equal "http://example.com", AppDomain.url
  end

  test "uses action_mailer port configuration over ENV" do
    ENV["APP_HOST"] = "example.com"
    ENV["APP_PORT"] = "3000"
    Rails.application.config.action_mailer.default_url_options = { host: "example.com", port: "4000" }

    assert_equal "http://example.com:4000", AppDomain.url
  end

  test "uses routes port configuration over ENV" do
    ENV["APP_HOST"] = "example.com"
    ENV["APP_PORT"] = "3000"
    Rails.application.routes.default_url_options = { host: "example.com", port: "5000" }

    assert_equal "http://example.com:5000", AppDomain.url
  end

  test "uses https when force_ssl is enabled" do
    ENV["APP_HOST"] = "example.com"
    ENV["APP_PORT"] = "3000"
    Rails.application.config.force_ssl = true

    assert_equal "https://example.com:3000", AppDomain.url
  ensure
    Rails.application.config.force_ssl = false
  end

  # New tests to cover specific lines

  test "uses action_mailer host configuration when available" do
    ENV["APP_HOST"] = "env-example.com"
    Rails.application.config.action_mailer.default_url_options = { host: "mailer-example.com" }

    assert_equal "http://mailer-example.com", AppDomain.url
  end

  test "uses routes host configuration when action_mailer host is not set" do
    ENV["APP_HOST"] = "env-example.com"
    Rails.application.routes.default_url_options = { host: "routes-example.com" }

    assert_equal "http://routes-example.com", AppDomain.url
  end

  test "uses action_mailer port when available" do
    ENV["APP_HOST"] = "example.com"
    ENV["APP_PORT"] = "3000"
    Rails.application.config.action_mailer.default_url_options = { port: "4000" }

    assert_equal "http://example.com:4000", AppDomain.url
  end

  test "uses http protocol when force_ssl is disabled" do
    ENV["APP_HOST"] = "example.com"
    Rails.application.config.force_ssl = false

    assert_equal "http://example.com", AppDomain.url
  end
end
