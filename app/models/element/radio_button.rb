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
class Element::RadioButton < ApplicationRecord
  has_one :element, as: :variant
end
