require "test_helper"

class Element::RadioButtonTest < ActiveSupport::TestCase
  test "radio button is displayed" do
    radio_button = Element::RadioButton.new
    assert radio_button.displayed?
  end
end
