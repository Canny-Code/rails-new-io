require "test_helper"

class Element::NullTest < ActiveSupport::TestCase
  setup do
    @null_element = Element::Null.new
  end

  test "null element is not displayed" do
    assert_not @null_element.displayed?
  end
end
