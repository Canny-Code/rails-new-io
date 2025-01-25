require "test_helper"
require_relative "../../support/git_test_helper"

class GitBackedModelTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers
  include GitTestHelper

  class TestModel
    include ActiveModel::Model
    include GitBackedModel

    attr_accessor :id, :name, :user, :created_at, :updated_at, :created_by

    def has_attribute?(attr)
      attr.to_s == "source_path"
    end

    def []=(attr, value)
      @attributes ||= {}
      @attributes[attr.to_s] = value
    end

    def [](attr)
      @attributes ||= {}
      if attr.to_s == "id"
        id
      else
        @attributes[attr.to_s]
      end
    end

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

  class TestModelWithoutSourcePath < TestModel
    def has_attribute?(attr)
      false
    end

    def source_path
      "test"
    end
  end

  class TestModelWithDynamicPath < TestModelWithoutSourcePath
    def source_path
      "#{name}-path"
    end

    def cleanup_after_push?
      name == "cleanup-me"
    end
  end

  class TestModelWithSourcePathAttribute < TestModel
    def has_attribute?(attr)
      false
    end

    def source_path_attribute
      "computed-path"
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
      updated_at: Time.now
    )

    # Set source_path through instance variable since it's not an attribute
    @model.instance_variable_set(:@source_path, Rails.root.join("tmp/test").to_s)

    FileUtils.mkdir_p(@model.source_path)
    setup_github_mocks
  end

  test "includes necessary methods" do
    assert_respond_to @model, :initial_git_commit
    assert_respond_to @model, :sync_to_git
    assert_respond_to @model, :repo
    assert_respond_to @model, :should_sync_to_git?
  end

  test "initial_git_commit creates repository and pushes files" do
    repo = mock("repo")
    repo.expects(:initialize_repository)
    repo.expects(:commit_changes).with(
      message: "Initial commit",
      tree_items: []
    )
    @model.stubs(:repo).returns(repo)

    @model.initial_git_commit
  end

  test "sync_to_git pushes files" do
    repo = mock("repo")
    repo.expects(:commit_changes).with(
      message: "Update test_model",
      tree_items: []
    )
    @model.stubs(:repo).returns(repo)

    @model.sync_to_git
  end

  test "sync_to_git handles errors through handle_git_error" do
    error = StandardError.new("Commit failed")
    repo = mock("repo")
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

  test "should_create_repository? returns false if source_path is blank" do
    @model.instance_variable_set(:@source_path, nil)
    assert_not @model.should_create_repository?
  end

  test "should_create_repository? returns true if source_path exists and not in test env" do
    Rails.env.stubs(:test?).returns(false)
    assert @model.should_create_repository?
  end

  test "should_create_repository? checks directory existence in test env" do
    Rails.env.stubs(:test?).returns(true)
    File.stubs(:directory?).with(@model.source_path).returns(true)
    assert @model.should_create_repository?
  end

  test "cleanup_after_push? returns false by default" do
    assert_not @model.cleanup_after_push?
  end

  test "source_path returns attribute value if available" do
    assert_equal Rails.root.join("tmp/test").to_s, @model.source_path
  end

  test "source_path uses database attribute when has_attribute? is true" do
    model = TestModel.new
    model[:source_path] = "/test/path"
    assert model.has_attribute?(:source_path), "Model should have source_path attribute"
    assert_equal "/test/path", model[:"source_path"]
    assert_equal "/test/path", model.source_path
  end

  test "source_path can be overridden in subclasses" do
    model = TestModelWithoutSourcePath.new
    assert_equal "test", model.source_path
  end

  test "dynamic source_path and cleanup_after_push behavior" do
    model = TestModelWithDynamicPath.new(name: "test")
    assert_equal "test-path", model.source_path
    assert_not model.cleanup_after_push?

    model.name = "cleanup-me"
    assert model.cleanup_after_push?
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

  test "source_path uses source_path_attribute when available" do
    model = TestModelWithSourcePathAttribute.new
    assert_equal "computed-path", model.source_path
  end

  test "initial_git_commit handles errors through handle_git_error" do
    error = StandardError.new("Repository initialization failed")
    repo = mock("repo")
    repo.expects(:initialize_repository).raises(error)
    @model.stubs(:repo).returns(repo)

    @model.expects(:handle_git_error).with(error)
    @model.initial_git_commit
  end
end
