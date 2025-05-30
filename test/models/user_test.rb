# == Schema Information
#
# Table name: users
#
#  id                   :integer          not null, primary key
#  admin                :boolean          default(FALSE), not null
#  email                :string
#  github_token         :text
#  github_username      :string           not null
#  image                :string
#  name                 :string
#  onboarding_completed :boolean          default(FALSE)
#  provider             :string
#  slug                 :string
#  uid                  :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_users_on_github_username  (github_username) UNIQUE
#  index_users_on_slug             (slug) UNIQUE
#
require "test_helper"

class UserTest < ActiveSupport::TestCase
end
