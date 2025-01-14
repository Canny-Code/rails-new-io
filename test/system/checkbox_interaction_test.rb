# frozen_string_literal: true

require "application_system_test_case"

class CheckboxInteractionTest < ApplicationSystemTestCase
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
    visit root_path
    click_on "Get in"
  end

  test "updates rails-flags when checkbox is toggled" do
    visit setup_recipes_path(slug: pages(:basic_setup).slug)

    assert_current_path setup_recipes_path(slug: pages(:basic_setup).slug)
    assert_selector ".menu-card-row"

    page.all("input[type='checkbox'][data-display-when='checked']").each do |checkbox|
      checkbox.click if checkbox.checked?
    end

    checkbox = find("input[type='checkbox'][id='main-tab-mains-skip-git']")

    assert_selector "#rails-flags", visible: :all
    assert_no_text "--skip-git"
    assert_no_text "--skip-docker"
    assert_no_text "--skip-action-mailer"

    checkbox.click

    assert_text "--skip-git"

    checkbox.click

    assert_no_text "--skip-git"
  end
end
