# == Schema Information
#
# Table name: app_changes
#
#  id               :integer          not null, primary key
#  applied_at       :datetime
#  configuration    :json
#  error_message    :text
#  success          :boolean
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  generated_app_id :integer          not null
#  ingredient_id    :integer          not null
#
# Indexes
#
#  index_app_changes_on_generated_app_id  (generated_app_id)
#  index_app_changes_on_ingredient_id     (ingredient_id)
#
# Foreign Keys
#
#  generated_app_id  (generated_app_id => generated_apps.id) ON DELETE => cascade
#  ingredient_id     (ingredient_id => ingredients.id) ON DELETE => cascade
#
require "test_helper"

class AppChangeTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
