# == Schema Information
#
# Table name: repositories
#
#  id         :integer          not null, primary key
#  github_url :string           not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_repositories_on_github_url  (github_url) UNIQUE
#  index_repositories_on_name        (name)
#  index_repositories_on_user_id     (user_id)
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
require "test_helper"

class RepositoryTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
