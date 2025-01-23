require "test_helper"
require_relative "../support/git_test_helper"

class InitializeUserDataRepositoryJobTest < ActiveSupport::TestCase
  include GitTestHelper

  def setup
    @user = users(:john)

    @repo_name = "rails-new-io-data-test"
  end

  test "does not create repository if it already exists" do
    # Stub before any GitHub operations
    User.any_instance.stubs(:github_username).returns("test-user")

    setup_github_mocks

    # Simulate repository already exists
    mock_client = mock("octokit_client")
    mock_client.expects(:repository?).with("test-user/#{DataRepositoryService.name_for_environment}").returns(true)
    Octokit::Client.stubs(:new).returns(mock_client)

    result = InitializeUserDataRepositoryJob.perform_now(@user.id)

    assert_nil result, "Job should return nil when repository already exists"
  end

  test "creates data repository if it does not exist" do
    # Stub before any GitHub operations
    User.any_instance.stubs(:github_username).returns("test-user")

    setup_github_mocks

    expect_github_operations(create_repo: true, expect_git_operations: true)

    result = InitializeUserDataRepositoryJob.perform_now(@user.id)

    assert result.is_a?(GitRepo), "Job should return a GitRepo object"
    assert_equal "https://github.com/test-user/#{@repo_name}", result.html_url
  end

  test "handles user not found" do
    assert_nothing_raised do
      result = InitializeUserDataRepositoryJob.perform_now(-1)

      assert_nil result, "Job should return nil when user not found"
    end
  end
end
