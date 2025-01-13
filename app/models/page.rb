# == Schema Information
#
# Table name: pages
#
#  id         :integer          not null, primary key
#  position   :integer          default(0), not null
#  slug       :string           not null
#  title      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_pages_on_position  (position)
#  index_pages_on_slug      (slug) UNIQUE
#  index_pages_on_title     (title)
#
class Page < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  has_many :groups, dependent: :destroy

  validates :title, presence: true, uniqueness: true
  validates :slug, uniqueness: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :slug_present

  default_scope { order(position: :asc) }

  private

  def slug_present
    if slug.nil? || slug.empty?
      errors.add(:slug, "can't be blank")
    end
  end
end
