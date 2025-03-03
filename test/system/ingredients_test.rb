require "application_system_test_case"

class IngredientsTest < ApplicationSystemTestCase
  setup do
    # Mock repository operations
    DataRepositoryService.any_instance.stubs(:push_app_files).returns(true)
    DataRepositoryService.any_instance.stubs(:initialize_repository).returns(true)

    @ingredient = ingredients(:rails_authentication)
    @user = users(:john)

    # Set up OmniAuth mock for system tests
    OmniAuth.config.test_mode = true
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

    # Visit root and click the auth link - this is the actual browser flow
    visit root_path
    click_on "Get in"
  end

  test "creating a new ingredient" do
    visit new_ingredient_path

    fill_in "Name", with: "Test Ingredient"
    fill_in "Description", with: "A test ingredient description"

    page.execute_script(<<~JS)
      document.querySelector('.CodeMirror').CodeMirror.setValue("gem 'test_gem'")
    JS

    fill_in "Category", with: "Authentication"

    click_on "Create Ingredient"

    assert_text "Ingredient was successfully created"
    assert_selector "h2", text: "Test Ingredient"
  end

  test "updating an ingredient" do
    visit edit_ingredient_path(@ingredient)

    fill_in "Name", with: "Updated Ingredient"
    fill_in "Description", with: "An updated description"
    click_on "Update Ingredient"

    assert_text "Ingredient was successfully updated"
    assert_text "Updated Ingredient"
  end

  test "showing validation errors" do
    visit new_ingredient_path

    fill_in "Name", with: ""
    click_on "Create Ingredient"

    assert_text "Name can't be blank"
    assert_text "Template content can't be blank"
  end

  test "deleting an ingredient" do
    visit ingredient_path(@ingredient)
    accept_confirm do
      click_on "Delete", match: :first
    end

    assert_text "Ingredient was successfully deleted"
  end
end
