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
class Element::TextField < ApplicationRecord
  has_one :element, as: :variant
end
