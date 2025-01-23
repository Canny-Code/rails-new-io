require "test_helper"

class GithubCodePushJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    @user = users(:john)
    @repo_name = "test-repo"
    @source_path = "/path/to/source"
    @cleanup_after_push = true
  end

  test "enqueues job with correct arguments" do
    assert_enqueued_with(job: GithubCodePushJob, args: [ @user.id, @repo_name, @source_path, @cleanup_after_push ]) do
      GithubCodePushJob.perform_later(@user.id, @repo_name, @source_path, @cleanup_after_push)
    end
  end

  test "performs job successfully" do
    response = Data.define(:html_url).new(html_url: "https://github.com/#{@user.github_username}/#{@repo_name}")

    mock_client = mock("octokit_client")
    mock_client.expects(:repository?).with("#{@user.github_username}/#{@repo_name}").returns(false)
    mock_client.expects(:create_repository).with(@repo_name, {
      private: false,
      auto_init: false,
      description: "Repository created via railsnew.io",
      default_branch: "main"
    }).returns(response)

    # Mock file system operations
    File.stubs(:directory?).with(@source_path).returns(true)
    Dir.stubs(:glob).with("#{@source_path}/**/*", File::FNM_DOTMATCH).returns([])

    # Mock commit operations
    mock_client.expects(:ref).with("#{@user.github_username}/#{@repo_name}", "heads/main").returns(
      Data.define(:object).new(object: Data.define(:sha).new(sha: "old_sha"))
    )
    mock_client.expects(:commit).with("#{@user.github_username}/#{@repo_name}", "old_sha").returns(
      Data.define(:commit).new(commit: Data.define(:tree).new(tree: Data.define(:sha).new(sha: "tree_sha")))
    )
    mock_client.expects(:create_tree).with(
      "#{@user.github_username}/#{@repo_name}",
      [
        {
          path: "README.md",
          mode: "100644",
          type: "blob",
          content: "# test-repo\n\nCreated via railsnew.io"
        }
      ],
      base_tree: "tree_sha"
    ).returns(Data.define(:sha).new(sha: "new_tree_sha"))
    mock_client.expects(:create_commit).with(
      "#{@user.github_username}/#{@repo_name}",
      "Initial commit",
      "new_tree_sha",
      "tree_sha",
      author: {
        name: @user.github_username,
        email: "#{@user.github_username}@users.noreply.github.com"
      }
    ).returns(Data.define(:sha).new(sha: "new_sha"))
    mock_client.expects(:update_ref).with(
      "#{@user.github_username}/#{@repo_name}",
      "heads/main",
      "new_sha"
    )

    Octokit::Client.stubs(:new).returns(mock_client)

    # Mock cleanup
    FileUtils.expects(:rm_rf).with(@source_path)

    GithubCodePushJob.perform_now(@user.id, @repo_name, @source_path, @cleanup_after_push)
  end
end
