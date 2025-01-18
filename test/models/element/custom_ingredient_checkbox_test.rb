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
#  index_element_custom_ingredient_checkboxes_on_ingredient_id  (ingredient_id)
#
# Foreign Keys
#
#  ingredient_id  (ingredient_id => ingredients.id)
#
require "test_helper"

class Element::CustomIngredientCheckboxTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
