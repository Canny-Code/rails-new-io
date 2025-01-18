# frozen_string_literal: true

require "test_helper"

class GroupBehaviorTest < ActiveSupport::TestCase
  test "returns stimulus attributes for generic_checkbox" do
    group = Group.new(behavior_type: "generic_checkbox")

    result = group.stimulus_attributes

    assert_equal "rails-flag-checkbox", result[:controller]
    assert_equal "#rails-flags", result[:"rails-flag-checkbox-generated-output-outlet"]

    assert_equal(
      {
        controller: "rails-flag-checkbox",
        "rails-flag-checkbox-generated-output-outlet": "#rails-flags"
      },
      result
    )
  end

  test "returns stimulus attributes for custom_ingredient_checkbox" do
    group = Group.new(behavior_type: "custom_ingredient_checkbox")

    result = group.stimulus_attributes

    assert_equal "custom-ingredient-checkbox", result[:controller]
    assert_equal "#custom_ingredients", result[:"custom-ingredient-checkbox-generated-output-outlet"]

    assert_equal(
      {
        controller: "custom-ingredient-checkbox",
        "custom-ingredient-checkbox-generated-output-outlet": "#custom_ingredients"
      },
      result
    )
  end

  test "returns empty hash for unknown behavior_type" do
    group = Group.new(behavior_type: "unknown")

    result = group.stimulus_attributes

    assert_equal({}, result)
  end
end
