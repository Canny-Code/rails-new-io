require "test_helper"

module Pages
  module Groups
    class ComponentTest < ActiveSupport::TestCase
      include Phlex::Testing::ViewHelper

      setup do
        @databases_group = groups(:databases)
        @dev_env_group = groups(:dev_env)
      end

      test "renders database choice group with correct stimulus attributes" do
        component = Component.new(group: @databases_group)

        Pages::Groups::SubGroups::Elements::RadioButton::Component.any_instance
        .stubs(:image_tag)
        .returns("image_tag_stub")

        html = render(component)

        assert_includes html, 'data-controller="radio-button-choice"'
        assert_includes html, 'data-radio-button-choice-generated-output-outlet="#database-choice"'
        assert_includes html, 'data-output-prefix="-d"'
      end

      test "renders generic checkbox group with correct stimulus attributes" do
        @dev_env_group.update!(behavior_type: "generic_checkbox")
        component = Component.new(group: @dev_env_group)

        html = render(component)

        assert_includes html, 'data-controller="check-box"'
        assert_includes html, 'data-check-box-generated-output-outlet="#rails-flags"'
      end
    end
  end
end
