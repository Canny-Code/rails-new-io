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
require "test_helper"

class CommitTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
