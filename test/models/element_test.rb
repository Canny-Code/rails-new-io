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
#  user_id            :integer          not null
#  variant_id         :string
#
# Indexes
#
#  index_elements_on_command_line_value           (command_line_value)
#  index_elements_on_label                        (label)
#  index_elements_on_position                     (position)
#  index_elements_on_sub_group_id                 (sub_group_id)
#  index_elements_on_user_id                      (user_id)
#  index_elements_on_variant_type_and_variant_id  (variant_type,variant_id)
#
# Foreign Keys
#
#  sub_group_id  (sub_group_id => sub_groups.id)
#  user_id       (user_id => users.id)
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

  test "allows the same label within group if it's in a different sub group" do
    page = pages(:custom_ingredients)
    group = page.groups.create!(title: "Test Group")
    sub_group1 = group.sub_groups.create!(title: "Sub Group 1")
    sub_group2 = group.sub_groups.create!(title: "Sub Group 2")

    checkbox1 = Element::RailsFlagCheckbox.create!(
      checked: false,
      display_when: "checked"
    )
    sub_group1.elements.create!(
      label: "Test Element",
      description: "Test Description",
      position: 0,
      variant: checkbox1,
      user: users(:john)
    )

    checkbox2 = Element::RailsFlagCheckbox.create!(
      checked: false,
      display_when: "checked"
    )
    element2 = sub_group2.elements.build(
      label: "Test Element", # Same label as element1
      description: "Another Description",
      position: 0,
      variant: checkbox2,
      user: users(:john)
    )

    assert element2.valid?
  end

  test "allows same label for different users in same sub_group" do
    page = pages(:custom_ingredients)
    group = page.groups.create!(title: "Test Group")
    sub_group = group.sub_groups.create!(title: "Sub Group")

    checkbox1 = Element::RailsFlagCheckbox.create!(
      checked: false,
      display_when: "checked"
    )
    sub_group.elements.create!(
      label: "Test Element",
      description: "Test Description",
      position: 0,
      variant: checkbox1,
      user: users(:john)
    )

    checkbox2 = Element::RailsFlagCheckbox.create!(
      checked: false,
      display_when: "checked"
    )
    element2 = sub_group.elements.build(
      label: "Test Element",
      description: "Another Description",
      position: 0,
      variant: checkbox2,
      user: users(:jane)
    )

    assert element2.valid?
  end

  test "prevents duplicate labels for same user in same sub_group" do
    page = pages(:custom_ingredients)
    group = page.groups.create!(title: "Test Group")
    sub_group = group.sub_groups.create!(title: "Sub Group")

    checkbox1 = Element::RailsFlagCheckbox.create!(
      checked: false,
      display_when: "checked"
    )
    sub_group.elements.create!(
      label: "Test Element",
      description: "Test Description",
      position: 0,
      variant: checkbox1,
      user: users(:john)
    )

    checkbox2 = Element::RailsFlagCheckbox.create!(
      checked: false,
      display_when: "checked"
    )
    element2 = sub_group.elements.build(
      label: "Test Element",
      description: "Another Description",
      position: 0,
      variant: checkbox2,
      user: users(:john)
    )

    assert_not element2.valid?
    assert_includes element2.errors[:label], "must be unique within the group and subgroup for the same user"
  end

  test "validates that variant exists" do
    # Test valid case
    page = pages(:custom_ingredients)
    group = page.groups.create!(title: "Test Group")
    sub_group = group.sub_groups.create!(title: "Sub Group")

    checkbox = Element::RailsFlagCheckbox.create!(checked: false)
    element = Element.new(
      label: "Test Element",
      variant_type: "Element::RailsFlagCheckbox",
      variant_id: checkbox.id,
      user: users(:john),
      sub_group: sub_group
    )
    assert element.valid?

    # Test invalid case with non-existent variant
    element = Element.new(
      label: "Test Element",
      variant_type: "Element::RailsFlagCheckbox",
      variant_id: 999999, # Non-existent ID
      user: users(:john),
      sub_group: sub_group
    )
    assert_not element.valid?
    assert_includes element.errors[:variant], "must exist"
  end
end
