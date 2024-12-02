require "test_helper"

class NotificationsHelperTest < ActionView::TestCase
  class MockNotification
    attr_reader :url
    def initialize(url)
      @url = url
    end
  end

  test "handles internal routes" do
    notification = MockNotification.new("/dashboard")
    assert_equal "/dashboard", safe_notification_url(notification)
  end

  test "handles valid external https urls" do
    notification = MockNotification.new("https://example.com")
    assert_equal "https://example.com", safe_notification_url(notification)
  end

  test "handles valid external http urls" do
    notification = MockNotification.new("http://example.com")
    assert_equal "http://example.com", safe_notification_url(notification)
  end

  test "returns # for blank urls" do
    notification = MockNotification.new(nil)
    assert_equal "#", safe_notification_url(notification)

    notification = MockNotification.new("")
    assert_equal "#", safe_notification_url(notification)
  end

  test "returns # for malformed urls" do
    notification = MockNotification.new("not a url")
    assert_equal "#", safe_notification_url(notification)

    notification = MockNotification.new("ftp://example.com")
    assert_equal "#", safe_notification_url(notification)
  end
end
