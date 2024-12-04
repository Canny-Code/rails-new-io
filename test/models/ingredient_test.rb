# == Schema Information
#
# Table name: ingredients
#
#  id               :integer          not null, primary key
#  category         :string
#  configures_with  :text
#  conflicts_with   :text
#  description      :text
#  name             :string           not null
#  requires         :text
#  template_content :text             not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  created_by_id    :integer          not null
#
# Indexes
#
#  index_ingredients_on_created_by_id  (created_by_id)
#  index_ingredients_on_name           (name) UNIQUE
#
# Foreign Keys
#
#  created_by_id  (created_by_id => users.id)
#
require "test_helper"

class IngredientTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
