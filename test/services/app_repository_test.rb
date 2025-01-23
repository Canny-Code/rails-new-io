require "test_helper"
require "fileutils"

class AppRepositoryTest < ActiveSupport::TestCase
  def setup
    @user = users(:john)
    @app = generated_apps(:blog_app)
    @source_path = Rails.root.join("tmp/test/source/#{@app.name}")
    @repo_path = Rails.root.join("tmp/test/repo/#{@app.name}")

    # Create temporary directories for testing
    FileUtils.mkdir_p(@source_path)
    FileUtils.mkdir_p(@repo_path)

    # Create some test files in source path
    File.write(File.join(@source_path, "test.rb"), "puts 'test'")
    File.write(File.join(@source_path, "Gemfile"), "source 'https://rubygems.org'")

    @app.source_path = @source_path.to_s
    @repo = AppRepository.new(
      user: @user,
      app_name: @app.name,
      source_path: @source_path.to_s,
      cleanup_after_push: true
    )

    # Mock GitHub client
    @mock_client = mock("octokit_client")
    Octokit::Client.stubs(:new).returns(@mock_client)
    @mock_client.stubs(:repository?).returns(true)

    # Mock basic GitHub API responses
    @ref_mock = mock("ref")
    @ref_mock.stubs(:object).returns(OpenStruct.new(sha: "old_sha"))

    @commit_mock = mock("commit")
    @commit_mock.stubs(:commit).returns(OpenStruct.new(tree: OpenStruct.new(sha: "tree_sha")))

    @tree_mock = mock("tree")
    @tree_mock.stubs(:sha).returns("new_tree_sha")

    @new_commit_mock = mock("new_commit")
    @new_commit_mock.stubs(:sha).returns("new_sha")
  end

  def teardown
    FileUtils.rm_rf(Rails.root.join("tmp/test"))
  end

  test "initializes with correct parameters" do
    assert_equal @user, @repo.user
    assert_equal @app.name, @repo.repo_name
    assert_equal @source_path.to_s, @repo.source_path
    assert @repo.cleanup_after_push
  end

  test "writes generated app files to repository" do
    @mock_client.expects(:ref).returns(@ref_mock)
    @mock_client.expects(:commit).returns(@commit_mock)
    @mock_client.expects(:create_tree).returns(@tree_mock)
    @mock_client.expects(:create_commit).returns(@new_commit_mock)
    @mock_client.expects(:update_ref)

    @repo.write_model(@app)
  end

  test "ensures repository has README.md" do
    @mock_client.expects(:ref).returns(@ref_mock)
    @mock_client.expects(:commit).returns(@commit_mock)
    @mock_client.expects(:create_tree).with(
      "#{@user.github_username}/#{@app.name}",
      includes(path: "README.md"),
      base_tree: "tree_sha"
    ).returns(@tree_mock)
    @mock_client.expects(:create_commit).returns(@new_commit_mock)
    @mock_client.expects(:update_ref)

    @repo.write_model(@app)
  end

  test "raises error for unsupported model type" do
    unsupported_model = User.new

    assert_raises(ArgumentError) do
      @repo.write_model(unsupported_model)
    end
  end

  test "provides correct repository description" do
    assert_equal "Generated Rails application", @repo.send(:repository_description)
  end

  test "cleans up source directory after push when cleanup_after_push is true" do
    @mock_client.expects(:ref).returns(@ref_mock)
    @mock_client.expects(:commit).returns(@commit_mock)
    @mock_client.expects(:create_tree).returns(@tree_mock)
    @mock_client.expects(:create_commit).returns(@new_commit_mock)
    @mock_client.expects(:update_ref)

    Rails.env.stubs(:development?).returns(false)
    @repo.write_model(@app)

    assert_not File.exist?(@source_path)
  end

  test "does not clean up source directory in development" do
    @mock_client.expects(:ref).returns(@ref_mock)
    @mock_client.expects(:commit).returns(@commit_mock)
    @mock_client.expects(:create_tree).returns(@tree_mock)
    @mock_client.expects(:create_commit).returns(@new_commit_mock)
    @mock_client.expects(:update_ref)

    Rails.env.stubs(:development?).returns(true)
    @repo.write_model(@app)

    assert File.exist?(@source_path)
  end
end
