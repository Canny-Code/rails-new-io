# == Schema Information
#
# Table name: sub_groups
#
#  id         :integer          not null, primary key
#  position   :integer          default(0)
#  title      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  group_id   :integer          not null
#
# Indexes
#
#  index_sub_groups_on_group_id  (group_id)
#  index_sub_groups_on_title     (title)
#
# Foreign Keys
#
#  group_id  (group_id => groups.id)
#
class SubGroup < ApplicationRecord
  belongs_to :group
  has_many :elements, dependent: :destroy

  validates :title, presence: true, uniqueness: { scope: :group_id }
end
