# == Schema Information
#
# Table name: element_rails_flag_checkboxes
#
#  id           :integer          not null, primary key
#  checked      :boolean
#  default      :boolean
#  display_when :string           default("checked")
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
require "test_helper"

class Element::RailsFlagCheckboxTest < ActiveSupport::TestCase
  setup do
    @checkbox = Element::RailsFlagCheckbox.new
  end

  test "checkbox is displayed" do
    assert @checkbox.displayed?
  end
end
