# == Schema Information
#
# Table name: pages
#
#  id         :integer          not null, primary key
#  slug       :string           not null
#  title      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_pages_on_slug   (slug) UNIQUE
#  index_pages_on_title  (title)
#
class Page < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  has_many :groups, dependent: :destroy

  validates :title, presence: true, uniqueness: true
  validates :slug, uniqueness: true
  validate :slug_present

  private

  def slug_present
    if slug.nil? || slug.empty?
      errors.add(:slug, "can't be blank")
    end
  end
end
