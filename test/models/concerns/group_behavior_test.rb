require "test_helper"

class GroupBehaviorTest < ActiveSupport::TestCase
  class DummyClass < ApplicationRecord
    include GroupBehavior
    self.table_name = "groups" # Use an existing table to avoid migration
  end

  test "stimulus_attributes returns correct attributes for generic_checkbox" do
    instance = DummyClass.new
    instance.behavior_type = "generic_checkbox"

    expected = {
      controller: "check-box",
      "check-box-generated-output-outlet": "#rails-flags"
    }

    assert_equal expected, instance.stimulus_attributes
  end
end
