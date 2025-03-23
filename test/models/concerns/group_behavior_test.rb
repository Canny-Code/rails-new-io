# frozen_string_literal: true

require "test_helper"

class GroupBehaviorTest < ActiveSupport::TestCase
  test "returns empty hash for unknown behavior_type" do
    group = Group.new(behavior_type: "unknown")

    result = group.stimulus_attributes

    assert_equal({}, result)
  end
end
