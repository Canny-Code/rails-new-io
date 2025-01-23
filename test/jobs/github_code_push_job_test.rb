require "test_helper"

class GithubCodePushJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    @user = users(:john)
    @repo_name = "test-repo"
    @source_path = "/path/to/source"
    @cleanup_after_push = true

    # Mock GitHub client
    @mock_client = mock("octokit_client")
    Octokit::Client.stubs(:new).returns(@mock_client)
    @mock_client.stubs(:repository?).returns(true)

    # Mock file system operations
    File.stubs(:directory?).with(@source_path).returns(true)
    Dir.stubs(:glob).with("#{@source_path}/**/*", File::FNM_DOTMATCH).returns([])

    # Mock basic GitHub API responses
    @ref_mock = mock("ref")
    @ref_mock.stubs(:object).returns(Data.define(:sha).new(sha: "old_sha"))

    @commit_mock = mock("commit")
    @commit_mock.stubs(:commit).returns(Data.define(:tree).new(tree: Data.define(:sha).new(sha: "tree_sha")))

    @tree_mock = mock("tree")
    @tree_mock.stubs(:sha).returns("new_tree_sha")

    @new_commit_mock = mock("new_commit")
    @new_commit_mock.stubs(:sha).returns("new_sha")
  end

  test "enqueues job with correct arguments" do
    assert_enqueued_with(job: GithubCodePushJob, args: [ @user.id, @repo_name, @source_path, @cleanup_after_push ]) do
      GithubCodePushJob.perform_later(@user.id, @repo_name, @source_path, @cleanup_after_push)
    end
  end

  test "calls GitRepo with correct arguments" do
    @mock_client.expects(:ref).returns(@ref_mock)
    @mock_client.expects(:commit).returns(@commit_mock)
    @mock_client.expects(:create_tree).returns(@tree_mock)
    @mock_client.expects(:create_commit).returns(@new_commit_mock)
    @mock_client.expects(:update_ref)

    GithubCodePushJob.perform_now(@user.id, @repo_name, @source_path, @cleanup_after_push)
  end
end
