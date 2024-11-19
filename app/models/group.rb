# == Schema Information
#
# Table name: groups
#
#  id            :integer          not null, primary key
#  behavior_type :string
#  title         :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  page_id       :integer          not null
#
# Indexes
#
#  index_groups_on_page_id  (page_id)
#  index_groups_on_title    (title)
#
# Foreign Keys
#
#  page_id  (page_id => pages.id)
#
class Group < ApplicationRecord
  include GroupBehavior

  belongs_to :page
  has_many :sub_groups, dependent: :destroy

  validates :title, presence: true, uniqueness: { scope: :page_id }
end
