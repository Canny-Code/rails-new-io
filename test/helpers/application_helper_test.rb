require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "full_title returns only application name when no title is set" do
    self.stubs(:content_for?).with(:title).returns(false)
    assert_equal Rails.application.config.application_name, full_title
  end
end
