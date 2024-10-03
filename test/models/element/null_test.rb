require "test_helper"

class Element::NullTest < ActiveSupport::TestCase
  test "null element is not displayed" do
    null_element = Element::Null.new

    assert_not null_element.displayed?
  end
end
