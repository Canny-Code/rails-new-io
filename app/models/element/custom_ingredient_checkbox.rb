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
#  ingredient_id  (ingredient_id => ingredients.id)
#
# frozen_string_literal: true

class Element::CustomIngredientCheckbox < ApplicationRecord
  has_one :element, as: :variant, dependent: :destroy
  belongs_to :ingredient

  validates :ingredient_id, presence: true, uniqueness: true

  def displayed?
    true
  end
end
