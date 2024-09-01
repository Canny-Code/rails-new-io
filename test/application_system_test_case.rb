require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  CI_PARAMS = [
    "--disable-gpu",
    "--no-sandbox",
    "--disable-dev-shm-usage"
  ]

  COMMON_PARAMS = [
    "--no-default-browser-check",
    "--no-first-run",
    "--disable-extensions",
    "--ignore-certificate-errors",
    "--homepage=about:blank",
    "--disable-search-engine-choice-screen"
  ]

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    ENV["CI"] ? add_options(CI_PARAMS, options) : options_for(COMMON_PARAMS, options)
  end

  SimpleCov.command_name "test:system" unless ActiveSupport::TestCase.skip_coverage?

  private

  def self.options_for(options_to_set, browser_options)
    options_to_set.each { |option| browser_options.add_argument(option) }
  end
end
