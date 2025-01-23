require "test_helper"

class InitializeUserDataRepositoryJobTest < ActiveSupport::TestCase
  def setup
    @user = users(:john)
    @mock_client = mock("octokit_client")
    Octokit::Client.stubs(:new).returns(@mock_client)
  end

  test "does not create repository if it already exists" do
    @mock_client.expects(:repository?).returns(true)
    @mock_client.expects(:create_repository).never

    InitializeUserDataRepositoryJob.perform_now(@user.id)
  end

  test "creates data repository if it does not exist" do
    @mock_client.expects(:repository?).returns(false)
    @mock_client.expects(:create_repository).once.returns(true)
    @mock_client.expects(:ref).returns(OpenStruct.new(object: OpenStruct.new(sha: "old_sha")))
    @mock_client.expects(:commit).returns(OpenStruct.new(commit: OpenStruct.new(tree: OpenStruct.new(sha: "tree_sha"))))
    @mock_client.expects(:create_tree).returns(OpenStruct.new(sha: "new_tree_sha"))
    @mock_client.expects(:create_commit).returns(OpenStruct.new(sha: "new_sha"))
    @mock_client.expects(:update_ref)

    InitializeUserDataRepositoryJob.perform_now(@user.id)
  end

  test "handles user not found" do
    assert_nothing_raised do
      InitializeUserDataRepositoryJob.perform_now(-1)
    end
  end
end
