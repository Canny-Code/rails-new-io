# == Schema Information
#
# Table name: groups
#
#  id            :integer          not null, primary key
#  behavior_type :string
#  description   :string
#  position      :integer          default(0)
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
require "test_helper"

class GroupTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
