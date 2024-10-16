# == Schema Information
#
# Table name: element_unclassifieds
#
#  id         :integer          not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Element::Unclassified < ApplicationRecord
  has_one :element, as: :variant

  def displayed?
    false
  end
end
