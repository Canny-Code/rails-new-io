require "application_system_test_case"

class PagesTest < ApplicationSystemTestCase
  def setup
    @user = users(:john)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: @user.provider,
      uid: @user.uid,
      info: {
        email: @user.email,
        name: @user.name,
        image: @user.image,
        nickname: @user.github_username
      }
    )
  end

  test "visiting the basic setup page" do
    visit setup_recipes_path(slug: pages(:basic_setup).slug)

    assert_selector "h3", text: "Databases", wait: 5
    assert_equal setup_recipes_path(slug: pages(:basic_setup).slug), current_path
  end

  test "can navigate between pages" do
    visit setup_recipes_path(slug: pages(:basic_setup).slug)

    click_on "Your Custom Ingredients"

    assert_selector "h3", text: "No ingredients yet", wait: 5
    assert_equal setup_recipes_path(slug: pages(:custom_ingredients).slug), current_path
  end
end
