# == Schema Information
#
# Table name: element_checkboxes
#
#  id           :integer          not null, primary key
#  checked      :boolean
#  default      :boolean
#  display_when :string           default("checked")
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class Element::Checkbox < ApplicationRecord
  has_one :element, as: :variant

  def displayed?
    true
  end
end
