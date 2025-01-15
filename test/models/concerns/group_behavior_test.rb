require "test_helper"

class GroupBehaviorTest < ActiveSupport::TestCase
  class DummyClass < ApplicationRecord
    include GroupBehavior
    self.table_name = "groups"
  end

  test "stimulus_attributes returns correct attributes for generic_checkbox" do
    instance = DummyClass.new
    instance.behavior_type = "generic_checkbox"

    result = instance.stimulus_attributes

    # Test each key individually to ensure coverage
    assert_equal "check-box", result[:controller]
    assert_equal "#rails-flags", result[:"check-box-generated-output-outlet"]

    # Also test the complete hash
    expected = {
      controller: "check-box",
      "check-box-generated-output-outlet": "#rails-flags"
    }
    assert_equal expected, result
  end

  test "stimulus_attributes returns correct attributes for custom_ingredient_checkbox" do
    instance = DummyClass.new
    instance.behavior_type = "custom_ingredient_checkbox"

    result = instance.stimulus_attributes

    # Test each key individually to ensure coverage
    assert_equal "check-box", result[:controller]
    assert_equal "#custom_ingredients", result[:"check-box-generated-output-outlet"]

    # Also test the complete hash
    expected = {
      controller: "check-box",
      "check-box-generated-output-outlet": "#custom_ingredients"
    }
    assert_equal expected, result
  end
end
