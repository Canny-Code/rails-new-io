# == Schema Information
#
# Table name: element_radio_buttons
#
#  id              :integer          not null, primary key
#  default         :boolean
#  selected_option :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class Element::RadioButtonTest < ActiveSupport::TestCase
  setup do
    @radio_button = Element::RadioButton.new
  end

  test "radio button is displayed" do
    assert @radio_button.displayed?
  end
end
