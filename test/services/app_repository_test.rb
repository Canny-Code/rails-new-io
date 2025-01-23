require "test_helper"
require "fileutils"
require_relative "../support/git_test_helper"

class AppRepositoryServiceTest < ActiveSupport::TestCase
  include GitTestHelper

  def setup
    @user = users(:john)
    @app = generated_apps(:saas_starter)
    @source_path = Rails.root.join("tmp/test/source/#{@app.name}")
    @repo_path = Rails.root.join("tmp/test/repo/#{@app.name}")
    @repo_name = @app.name

    # Create temporary directories for testing
    FileUtils.mkdir_p(@source_path)
    FileUtils.mkdir_p(@repo_path)

    # Create some test files in source path
    File.write(File.join(@source_path, "test.rb"), "puts 'test'")
    File.write(File.join(@source_path, "Gemfile"), "source 'https://rubygems.org'")

    @app.source_path = @source_path.to_s
    @repo = AppRepositoryService.new(@app)

    setup_github_mocks
  end

  def teardown
    FileUtils.rm_rf(Rails.root.join("tmp/test"))
  end

  test "initializes with correct parameters" do
    assert_equal @user, @repo.user
    assert_equal @app, @repo.generated_app
  end

  test "writes generated app files to repository" do
    expect_github_operations(expect_git_operations: true)
    @repo.push_app_files(source_path: @source_path.to_s)
  end

  test "ensures repository has README.md and source files" do
    @mock_client.expects(:ref).returns(@ref_mock)
    @mock_client.expects(:commit).returns(@commit_mock)
    @mock_client.expects(:create_tree).with(
      "#{@user.github_username}/#{@app.name}",
      [
        {
          path: "README.md",
          mode: "100644",
          type: "blob",
          content: "# #{@app.name}\n\nCreated via railsnew.io"
        },
        {
          path: "Gemfile",
          mode: "100644",
          type: "blob",
          content: "source 'https://rubygems.org'"
        },
        {
          path: "test.rb",
          mode: "100644",
          type: "blob",
          content: "puts 'test'"
        }
      ],
      base_tree: "tree_sha"
    ).returns(@tree_mock)
    @mock_client.expects(:create_commit).returns(@new_commit_mock)
    @mock_client.expects(:update_ref)

    @repo.push_app_files(source_path: @source_path.to_s)
  end

  test "skips pushing files if source directory doesn't exist" do
    FileUtils.rm_rf(@source_path)
    # No git operations should be called
    @mock_client.expects(:ref).never
    @mock_client.expects(:commit).never
    @mock_client.expects(:create_tree).never
    @mock_client.expects(:create_commit).never
    @mock_client.expects(:update_ref).never

    result = @repo.push_app_files(source_path: @source_path.to_s)
    assert_nil result
  end

  test "initializes repository with correct settings" do
    @app.expects(:create_github_repo!).returns(true)
    expect_github_operations(create_repo: true)
    @repo.initialize_repository
  end
end
