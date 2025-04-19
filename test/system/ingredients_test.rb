require "application_system_test_case"

class IngredientsTest < ApplicationSystemTestCase
  setup do
    # Mock repository operations
    DataRepositoryService.any_instance.stubs(:push_app_files).returns(true)
    DataRepositoryService.any_instance.stubs(:initialize_repository).returns(true)

    @ingredient = ingredients(:rails_authentication)
    @user = users(:john)

    # Mock GitHub API calls
    mock_client = mock("octokit_client")
    ref_response = Data.define(:object).new(object: Data.define(:sha).new(sha: "old_sha"))
    commit_tree = Data.define(:sha).new(sha: "tree_sha")
    commit_data = Data.define(:tree).new(tree: commit_tree)
    commit = Data.define(:commit, :sha).new(commit: commit_data, sha: "old_sha")
    new_tree = Data.define(:sha).new(sha: "new_tree_sha")
    new_commit = Data.define(:sha).new(sha: "new_sha")

    mock_client.stubs(:repository?).returns(true)
    mock_client.stubs(:ref).returns(ref_response)
    mock_client.stubs(:commit).returns(commit)
    mock_client.stubs(:create_tree).returns(new_tree)
    mock_client.stubs(:create_commit).returns(new_commit)
    mock_client.stubs(:update_ref).returns(true)

    Octokit::Client.stubs(:new).returns(mock_client)

    # Set up OmniAuth test mode
    OmniAuth.config.test_mode = true
  end

  test "creating a new ingredient" do
    # Set up OmniAuth for john
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new({
      provider: "github",
      uid: @user.uid,
      info: {
        email: @user.email,
        name: @user.name,
        image: @user.image
      },
      credentials: { token: "mock_token" },
      extra: {
        raw_info: {
          login: @user.github_username
        }
      }
    })

    # Login as john
    visit root_path
    click_on "Get in"

    visit new_ingredient_path

    fill_in "Name", with: "Test Ingredient"
    fill_in "Description", with: "A test ingredient description"

    page.execute_script(<<~JS)
      document.querySelector('textarea[name="ingredient[template_content]"] + div[class*="CodeMirror"]').CodeMirror.setValue("gem 'test_gem'")
    JS

    fill_in "ingredient[category]", with: "Authentication"
    fill_in "ingredient[sub_category]", with: "Devise"

    click_on "Create Ingredient"

    assert_text "Ingredient was successfully created"
    assert_selector "h2", text: "Test Ingredient"
  end

  test "rails-new-io user creating an ingredient adds it to the correct page group" do
    # Set up rails-new-io user
    rails_new_io_user = users(:rails_new_io)
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new({
      provider: "github",
      uid: rails_new_io_user.uid,
      info: {
        email: rails_new_io_user.email,
        name: rails_new_io_user.name,
        image: rails_new_io_user.image
      },
      credentials: { token: "mock_token" },
      extra: {
        raw_info: {
          login: "rails-new-io"
        }
      }
    })

    # Login as rails-new-io
    visit root_path
    click_on "Get in"

    visit new_ingredient_path

    fill_in "Name", with: "RSpec"
    fill_in "Description", with: "RSpec testing framework"

    select "Testing", from: "Page"
    fill_in "ingredient[category]", with: "Alternative Frameworks"
    fill_in "ingredient[sub_category]", with: "RSpec"


    page.execute_script(<<~JS)
      document.querySelector('textarea[name="ingredient[template_content]"] + div[class*="CodeMirror"]').CodeMirror.setValue("gem 'rspec'")
    JS

    click_on "Create Ingredient"

    assert_text "Ingredient was successfully created"

    # Visit the Testing page through the recipe setup flow
    visit setup_recipes_path("testing")

    # Verify the group and checkbox exist
    assert_selector "h3", text: "Alternative Frameworks"
    assert_selector "li.menu-card-row label", text: "RSpec"
  end

  test "updating an ingredient" do
    # Set up OmniAuth for john
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new({
      provider: "github",
      uid: @user.uid,
      info: {
        email: @user.email,
        name: @user.name,
        image: @user.image
      },
      credentials: { token: "mock_token" },
      extra: {
        raw_info: {
          login: @user.github_username
        }
      }
    })

    # Login as john
    visit root_path
    click_on "Get in"

    # Wait for authentication to complete
    assert_selector "button", text: "Logout", wait: 5

    # Verify we're on the dashboard
    assert_current_path "/dashboard"

    # Navigate to ingredients index first
    visit ingredients_path
    assert_current_path "/ingredients"

    # Now visit the edit page
    visit edit_ingredient_path(@ingredient)
    assert_current_path "/ingredients/#{@ingredient.id}/edit"

    fill_in "Name", with: "Updated Ingredient"
    fill_in "Description", with: "An updated description"
    click_on "Update Ingredient"

    assert_text "Ingredient was successfully updated"
    assert_text "Updated Ingredient"
  end

  test "showing validation errors" do
    # Set up OmniAuth for john
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new({
      provider: "github",
      uid: @user.uid,
      info: {
        email: @user.email,
        name: @user.name,
        image: @user.image
      },
      credentials: { token: "mock_token" },
      extra: {
        raw_info: {
          login: @user.github_username
        }
      }
    })

    # Login as john
    visit root_path
    click_on "Get in"

    visit new_ingredient_path

    fill_in "Name", with: ""
    click_on "Create Ingredient"

    assert_text "Name can't be blank"
    assert_text "Template content can't be blank"
  end

  test "deleting an ingredient" do
    # Set up OmniAuth for john
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new({
      provider: "github",
      uid: @user.uid,
      info: {
        email: @user.email,
        name: @user.name,
        image: @user.image
      },
      credentials: { token: "mock_token" },
      extra: {
        raw_info: {
          login: @user.github_username
        }
      }
    })

    # Login as john
    visit root_path
    click_on "Get in"

    visit ingredient_path(@ingredient)
    accept_confirm do
      click_on "Delete", match: :first
    end

    assert_text "Ingredient was successfully deleted"
  end
end
