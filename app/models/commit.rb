# == Schema Information
#
# Table name: commits
#
#  id             :integer          not null, primary key
#  message        :text             not null
#  parent_sha     :string
#  sha            :string           not null
#  state_snapshot :json             not null
#  versioned_type :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  author_id      :integer          not null
#  versioned_id   :integer          not null
#
# Indexes
#
#  index_commits_on_author_id  (author_id)
#  index_commits_on_sha        (sha) UNIQUE
#  index_commits_on_versioned  (versioned_type,versioned_id)
#
# Foreign Keys
#
#  author_id  (author_id => users.id)
#
class Commit < ApplicationRecord
  belongs_to :versioned, polymorphic: true
  belongs_to :author, class_name: "User"

  validates :sha, presence: true, uniqueness: true
  validates :message, presence: true
  validates :state_snapshot, presence: true

  before_create :generate_sha

  def parent
    return nil if parent_sha.blank?
    self.class.find_by(sha: parent_sha)
  end

  def restore!
    versioned.update!(state_snapshot)
  end

  private

  def generate_sha
    self.sha = Digest::SHA1.hexdigest(
      [ versioned_type, versioned_id, message, Time.current.to_f ].join("-")
    )
  end
end
