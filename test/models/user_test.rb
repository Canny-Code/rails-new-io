# == Schema Information
#
# Table name: users
#
#  id         :integer          not null, primary key
#  email      :string
#  image      :string
#  name       :string
#  provider   :string
#  slug       :string
#  uid        :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_users_on_slug  (slug) UNIQUE
#
require "test_helper"

class UserTest < ActiveSupport::TestCase
end
