require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  unless ENV["SKIP_COVERAGE"] == "1"
    SimpleCov.command_name "test:system"
  end
end
