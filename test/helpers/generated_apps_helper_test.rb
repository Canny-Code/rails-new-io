require "test_helper"

class GeneratedAppsHelperTest < ActionView::TestCase
  test "status_color returns correct classes for pending status" do
    assert_equal "bg-yellow-100 text-yellow-800", status_color("pending")
  end

  test "status_color returns correct classes for processing status" do
    assert_equal "bg-blue-100 text-blue-800", status_color("processing")
  end

  test "status_color returns correct classes for completed status" do
    assert_equal "bg-green-100 text-green-800", status_color("completed")
  end

  test "status_color returns correct classes for failed status" do
    assert_equal "bg-red-100 text-red-800", status_color("failed")
  end

  test "status_color returns default classes for unknown status" do
    assert_equal "bg-gray-100 text-gray-800", status_color("unknown")
  end
end
