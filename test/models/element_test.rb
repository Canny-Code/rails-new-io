# == Schema Information
#
# Table name: elements
#
#  id                 :integer          not null, primary key
#  command_line_value :string
#  description        :text
#  image_path         :string
#  label              :string           not null
#  position           :integer
#  variant_type       :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  sub_group_id       :integer
#  variant_id         :string
#
# Indexes
#
#  index_elements_on_command_line_value           (command_line_value)
#  index_elements_on_label                        (label)
#  index_elements_on_position                     (position)
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

  test "sets command_line_value before saving" do
    element = elements(:database_trilogy)

    element.save

    assert_equal "trilogy", element.command_line_value
  end

  test "updates command_line_value when label changes" do
    element = elements(:database_trilogy)
    element.reload.update!(label: "CockroachDB")

    assert_equal "cockroachdb", element.command_line_value
  end

  test "validates uniqueness of label within group" do
    page = pages(:custom_ingredients)
    group = page.groups.create!(title: "Test Group")
    sub_group1 = group.sub_groups.create!(title: "Sub Group 1")
    sub_group2 = group.sub_groups.create!(title: "Sub Group 2")

    checkbox1 = Element::RailsFlagCheckbox.create!(
      checked: false,
      display_when: "checked"
    )
    element1 = sub_group1.elements.create!(
      label: "Test Element",
      description: "Test Description",
      position: 0,
      variant: checkbox1
    )

    checkbox2 = Element::RailsFlagCheckbox.create!(
      checked: false,
      display_when: "checked"
    )
    element2 = sub_group2.elements.build(
      label: "Test Element", # Same label as element1
      description: "Another Description",
      position: 0,
      variant: checkbox2
    )

    assert_not element2.valid?
    assert_includes element2.errors[:label], "must be unique within the group"
  end
end
