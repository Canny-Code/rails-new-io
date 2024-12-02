require "test_helper"

class LogEntriesHelperTest < ActionView::TestCase
  test "returns correct color classes for different log levels" do
    assert_equal "bg-red-50", log_level_color(:error)
    assert_equal "bg-yellow-50", log_level_color(:warn)
    assert_equal "bg-white", log_level_color(:info)
    assert_equal "bg-white", log_level_color(:debug) # tests default case
  end

  test "handles string log levels" do
    assert_equal "bg-red-50", log_level_color("error")
    assert_equal "bg-yellow-50", log_level_color("warn")
    assert_equal "bg-white", log_level_color("info")
  end
end
