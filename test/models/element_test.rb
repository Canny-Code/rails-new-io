# == Schema Information
#
# Table name: elements
#
#  id           :integer          not null, primary key
#  label        :string           not null
#  variant_type :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  sub_group_id :integer
#  variant_id   :string
#
# Indexes
#
#  index_elements_on_label                        (label)
#  index_elements_on_sub_group_id                 (sub_group_id)
#  index_elements_on_variant_type_and_variant_id  (variant_type,variant_id)
#
# Foreign Keys
#
#  sub_group_id  (sub_group_id => sub_groups.id)
#
require "test_helper"

class ElementTest < ActiveSupport::TestCase
  test "#null returns a new Element with Null variant" do
    element = Element.null
    assert_equal "Element::Null", element.variant_type
  end

  test "#variant returns Null variant when super is nil" do
    element = Element.new
    assert_instance_of Element::Null, element.variant
  end

  test "#displayed? delegates to variant" do
    element = Element.new(variant: Element::RadioButton.new)
    assert element.displayed?
  end
end
