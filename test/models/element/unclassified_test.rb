require "test_helper"

class Element::UnclassifiedTest < ActiveSupport::TestCase
  test "unclassified element is not displayed" do
    unclassified_element = Element::Unclassified.new

    assert_not unclassified_element.displayed?
  end
end
