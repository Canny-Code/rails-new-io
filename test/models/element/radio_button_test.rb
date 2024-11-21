class Element::RadioButtonTest < ActiveSupport::TestCase
  setup do
    @radio_button = Element::RadioButton.new
  end

  test "radio button is displayed" do
    assert @radio_button.displayed?
  end
end
