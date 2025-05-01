require "test_helper"
require "support/phlex_component_test_case"

class Onboarding::Explanation::ComponentTest < PhlexComponentTestCase
  include ActionView::TestCase::Behavior

  def test_renders_markdown_content
    content = "# Hello\n\nThis is a test"
    render Onboarding::Explanation::Component.new(content: content)

    assert_select "div.bg-yellow-50"
    assert_select "div.flex.text-4xl", text: "👋"
    assert_select "h1", text: "Hello"
    assert_select "p", text: "This is a test"
  end

  def test_renders_with_custom_emoji
    render Onboarding::Explanation::Component.new(content: "Test", emoji: "🎉")
    assert_select "div.flex.text-4xl", text: "🎉"
  end

  def test_renders_links_with_target_blank
    content = "[Test Link](https://example.com)"
    render Onboarding::Explanation::Component.new(content: content)

    assert_select "a[href='https://example.com'][target='_blank'][rel='noopener noreferrer']", text: "Test Link"
  end
end
