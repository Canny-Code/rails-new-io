# == Schema Information
#
# Table name: element_custom_ingredient_checkboxes
#
#  id            :integer          not null, primary key
#  checked       :boolean
#  default       :boolean
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  ingredient_id :integer          not null
#
# Indexes
#
#  index_element_custom_ingredient_checkboxes_on_ingredient_id   (ingredient_id)
#  index_element_custom_ingredient_checkboxes_unique_ingredient  (ingredient_id) UNIQUE
#  unique_ingredient_checkbox                                    (ingredient_id) UNIQUE
#
# Foreign Keys
#
#  ingredient_id  (ingredient_id => ingredients.id) ON DELETE => cascade
#
require "test_helper"

class Element::CustomIngredientCheckboxTest < ActiveSupport::TestCase
  test "checkbox is always displayed" do
    checkbox = Element::CustomIngredientCheckbox.new
    assert checkbox.displayed?
  end
end
