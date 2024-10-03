# == Schema Information
#
# Table name: element_text_fields
#
#  id            :integer          not null, primary key
#  default_value :string
#  max_length    :integer
#  value         :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
require "test_helper"

class Element::TextFieldTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
