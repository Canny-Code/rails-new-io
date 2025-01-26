require "test_helper"

class AppRepositoryServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:john)
    @user.stubs(:github_token).returns("fake-token")
    @generated_app = generated_apps(:pending_app)
    @service = AppRepositoryService.new(@generated_app)
    @repository_name = "test-repo"
  end

  test "initializes repository and updates generated app" do
    response = Data.define(:html_url).new(html_url: "https://github.com/#{@user.github_username}/#{@repository_name}")

    mock_client = mock("octokit_client")
    mock_client.expects(:repository?).with("#{@user.github_username}/#{@repository_name}").returns(false)
    mock_client.expects(:create_repository).with(
      @repository_name,
      private: false,
      auto_init: false,
      description: "Repository created via railsnew.io",
      default_branch: "main"
    ).returns(response)

    Octokit::Client.stubs(:new).returns(mock_client)

    @generated_app.name = @repository_name
    result = @service.initialize_repository
    assert_equal response.html_url, result.html_url

    # Verify GeneratedApp was updated
    @generated_app.reload
    assert_equal @repository_name, @generated_app.github_repo_name
    assert_equal response.html_url, @generated_app.github_repo_url
  end

  test "pushes app files to repository" do
    source_path = "/tmp/test-app"
    FileUtils.mkdir_p(source_path)
    File.write(File.join(source_path, "test.rb"), "puts 'test'")

    @generated_app.update!(github_repo_name: @repository_name)

    mock_client = mock("octokit_client")
    # First ref call to get base tree SHA
    mock_client.expects(:ref).with("#{@user.github_username}/#{@repository_name}", "heads/main").returns(
      Data.define(:object).new(object: Data.define(:sha).new(sha: "old_sha"))
    )
    mock_client.expects(:commit).with("#{@user.github_username}/#{@repository_name}", "old_sha").returns(
      Data.define(:commit, :sha).new(
        commit: Data.define(:tree).new(tree: Data.define(:sha).new(sha: "tree_sha")),
        sha: "old_sha"
      )
    )
    mock_client.expects(:create_tree).with(
      "#{@user.github_username}/#{@repository_name}",
      [
        {
          path: "README.md",
          mode: "100644",
          type: "blob",
          content: "# #{@generated_app.name}\n\nCreated via railsnew.io"
        },
        {
          path: "test.rb",
          mode: "100644",
          type: "blob",
          content: "puts 'test'"
        }
      ],
      base_tree: "tree_sha"
    ).returns(Data.define(:sha).new(sha: "new_tree_sha"))

    # Second ref call to get latest commit SHA
    mock_client.expects(:ref).with("#{@user.github_username}/#{@repository_name}", "heads/main").returns(
      Data.define(:object).new(object: Data.define(:sha).new(sha: "old_sha"))
    )

    mock_client.expects(:create_commit).with(
      "#{@user.github_username}/#{@repository_name}",
      "Initial commit",
      "new_tree_sha",
      "old_sha",  # This should match the SHA from the second ref call
      author: {
        name: @user.name,
        email: @user.email
      }
    ).returns(Data.define(:sha).new(sha: "new_sha"))

    mock_client.expects(:update_ref).with(
      "#{@user.github_username}/#{@repository_name}",
      "heads/main",
      "new_sha"
    )

    Octokit::Client.stubs(:new).returns(mock_client)

    result = @service.push_app_files(source_path: source_path)
    assert_equal "new_sha", result.sha
  ensure
    FileUtils.rm_rf(source_path)
  end

  test "skips pushing files for non-existent source path" do
    # No client should be created since we're skipping
    Octokit::Client.expects(:new).never

    result = @service.push_app_files(source_path: "/nonexistent/path")
    assert_nil result
  end
end
