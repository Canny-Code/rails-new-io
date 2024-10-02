# == Schema Information
#
# Table name: element_text_fields
#
#  id            :integer          not null, primary key
#  default_value :string
#  max_length    :integer
#  value         :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
require "test_helper"

class Element::TextFieldTest < ActiveSupport::TestCase
  test "text field is displayed" do
    text_field = Element::TextField.new

    assert text_field.displayed?
  end
end
