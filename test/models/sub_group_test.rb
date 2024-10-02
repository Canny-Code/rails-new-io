# == Schema Information
#
# Table name: sub_groups
#
#  id         :integer          not null, primary key
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
require "test_helper"

class SubGroupTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
