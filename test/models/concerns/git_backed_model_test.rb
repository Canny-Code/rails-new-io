require "test_helper"
require_relative "../../support/git_test_helper"

class GitBackedModelTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers
  include GitTestHelper

  class TestModel
    include ActiveModel::Model
    include GitBackedModel

    attr_accessor :id, :name, :user, :created_at, :updated_at, :created_by, :workspace_path

    def changed
      [ "name" ]
    end

    def changes
      { "name" => [ "old", "new" ] }
    end

    def self.name
      "TestModel"
    end

    def model_name
      @_model_name ||= ActiveModel::Name.new(self.class)
    end
  end

  def setup
    @user = users(:john)
    @repo_name = DataRepositoryService.name_for_environment

    @model = TestModel.new(
      id: 1,
      name: "test",
      user: @user,
      created_at: Time.now,
      updated_at: Time.now,
      workspace_path: Rails.root.join("tmp/test").to_s
    )

    FileUtils.mkdir_p(@model.workspace_path)
    setup_github_mocks
  end

  test "includes necessary methods" do
    assert_respond_to @model, :initial_git_commit
    assert_respond_to @model, :sync_to_git
    assert_respond_to @model, :repo
    assert_respond_to @model, :should_sync_to_git?
  end

  test "initial_git_commit creates repository and pushes files" do
    repo = mock("git_repository")
    repo.expects(:initialize_repository)
    repo.expects(:commit_changes).with(
      message: "Initial commit",
      tree_items: []
    )
    @model.stubs(:repo).returns(repo)

    @model.initial_git_commit
  end

  test "initial_git_commit handles errors through handle_git_error" do
    error = StandardError.new("Repository initialization failed")
    repo = mock("git_repository")
    repo.expects(:initialize_repository).raises(error)
    @model.stubs(:repo).returns(repo)

    @model.expects(:handle_git_error).with(error)
    @model.initial_git_commit
  end

  test "sync_to_git pushes files" do
    repo = mock("git_repository")
    repo.expects(:commit_changes).with(
      message: "Update test_model",
      tree_items: []
    )
    @model.stubs(:repo).returns(repo)

    @model.sync_to_git
  end

  test "sync_to_git handles errors through handle_git_error" do
    error = StandardError.new("Commit failed")
    repo = mock("git_repository")
    repo.expects(:commit_changes).raises(error)
    @model.stubs(:repo).returns(repo)

    @model.expects(:handle_git_error).with(error)
    @model.sync_to_git
  end

  test "repo returns nil if should_create_repository? is false" do
    @model.stubs(:should_create_repository?).returns(false)
    assert_nil @model.repo
  end

  test "repo returns AppRepositoryService for GeneratedApp" do
    app = GeneratedApp.new(
      app_status: app_statuses(:completed_api_status),
      user: @user,
      name: "test-app"
    )
    app.stubs(:should_create_repository?).returns(true)
    repo = app.send(:repo)
    assert_instance_of AppRepositoryService, repo
  end

  test "repo returns DataRepositoryService for other models" do
    @model.stubs(:should_create_repository?).returns(true)
    repo = @model.send(:repo)
    assert_instance_of DataRepositoryService, repo
  end

  test "should_sync_to_git? returns true if there are non-timestamp changes" do
    assert @model.should_sync_to_git?
  end

  test "should_sync_to_git? returns false if there are only timestamp changes" do
    @model.stubs(:changed).returns([ "created_at", "updated_at" ])
    assert_not @model.should_sync_to_git?
  end

  test "should_create_repository? returns false if workspace_path is blank" do
    @model.workspace_path = nil
    assert_not @model.should_create_repository?
  end

  test "should_create_repository? returns true if workspace_path exists and not in test env" do
    Rails.env.stubs(:test?).returns(false)
    assert @model.should_create_repository?
  end

  test "should_create_repository? checks directory existence in test env" do
    Rails.env.stubs(:test?).returns(true)

    # Stub all File.directory? calls to return false by default
    File.stubs(:directory?).returns(false)
    # Only return true for the specific path we care about
    File.stubs(:directory?).with(@model.workspace_path).returns(true)

    assert @model.should_create_repository?
  end
  test "workspace_path returns attribute value if available" do
    assert_equal Rails.root.join("tmp/test").to_s, @model.workspace_path
  end

  test "change_description returns formatted changes" do
    assert_equal "name: old -> new", @model.change_description
  end

  test "handle_git_error raises error by default" do
    error = StandardError.new("Test error")
    assert_raises(StandardError) { @model.handle_git_error(error) }
  end

  test "handle_git_error calls on_git_error if available" do
    error = StandardError.new("Test error")
    @model.stubs(:on_git_error)
    @model.expects(:on_git_error).with(error)
    @model.handle_git_error(error)
  end

  test "uses correct repository class for GeneratedApp" do
    app = GeneratedApp.new(
      app_status: app_statuses(:completed_api_status),
      user: @user,
      name: "test-app"
    )
    app.stubs(:should_create_repository?).returns(true)
    repo = app.send(:repo)
    assert_instance_of AppRepositoryService, repo
  end

  test "uses DataRepositoryService for other models" do
    @model.stubs(:should_create_repository?).returns(true)
    repo = @model.send(:repo)
    assert_instance_of DataRepositoryService, repo
  end
end
