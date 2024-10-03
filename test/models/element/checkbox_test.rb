# == Schema Information
#
# Table name: element_checkboxes
#
#  id         :integer          not null, primary key
#  checked    :boolean
#  default    :boolean
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require "test_helper"

class Element::CheckboxTest < ActiveSupport::TestCase
  test "checkbox is displayed" do
    checkbox = Element::Checkbox.new
    assert checkbox.displayed?
  end
end
