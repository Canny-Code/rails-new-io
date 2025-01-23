require "test_helper"
require_relative "../../support/git_test_helper"

class GitBackedModelTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers
  include GitTestHelper

  class TestModel
    include ActiveModel::Model
    include GitBackedModel

    attr_accessor :id, :name, :user, :created_at, :updated_at, :created_by

    def self.has_attribute?(attr)
      attr.to_s == "source_path"
    end

    def []=(attr, value)
      instance_variable_set("@#{attr}", value)
    end

    def [](attr)
      if attr.to_s == "id"
        id
      else
        instance_variable_get("@#{attr}")
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
    def self.has_attribute?(attr)
      false
    end

    git_backed_options(source_path: "test")
  end

  class TestModelWithDynamicOptions < TestModelWithoutSourcePath
    git_backed_options(
      source_path: -> { "#{name}-path" },
      cleanup_after_push: -> { name == "cleanup-me" }
    )
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

  def teardown
    # Reset git_backed_options after each test
    TestModel.git_backed_options({})
    TestModelWithoutSourcePath.git_backed_options({})
    TestModelWithDynamicOptions.git_backed_options({})

    # Reset any instance variables
    @model.remove_instance_variable(:@source_path) if @model.instance_variable_defined?(:@source_path)
  end

  test "includes necessary methods" do
    assert_respond_to @model, :initial_git_commit
    assert_respond_to @model, :sync_to_git
    assert_respond_to @model, :repo
    assert_respond_to @model, :should_sync_to_git?
  end

  test "responds to git_backed_options" do
    assert_respond_to TestModel, :git_backed_options
  end

  test "configures git_backed_options" do
    TestModel.git_backed_options(source_path: "test")
    assert_equal "test", TestModel.get_git_backed_options[:source_path]
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

  test "cleanup_after_push? returns configured value" do
    TestModel.git_backed_options(cleanup_after_push: true)
    assert @model.cleanup_after_push?
  end

  test "cleanup_after_push? executes proc if configured" do
    TestModel.git_backed_options(cleanup_after_push: -> { true })
    assert @model.cleanup_after_push?
  end

  test "source_path returns configured value" do
    klass = Class.new(TestModel) do
      def self.has_attribute?(attr)
        false
      end

      def self.name
        "TestModelConfigured"
      end
    end
    Object.const_set("TestModelConfigured", klass)

    klass.git_backed_options(source_path: "test")

    model = klass.new(
      id: 1,
      name: "test",
      user: @user,
      created_at: Time.now,
      updated_at: Time.now
    )

    result = model.source_path
    assert_equal "test", result
  ensure
    Object.send(:remove_const, "TestModelConfigured") if Object.const_defined?("TestModelConfigured")
  end

  test "source_path executes proc if configured" do
    model = TestModelWithoutSourcePath.new(
      id: 1,
      name: "test",
      user: @user,
      created_at: Time.now,
      updated_at: Time.now
    )

    TestModelWithoutSourcePath.git_backed_options(source_path: -> { "test" })
    assert_equal "test", model.source_path
  end

  test "source_path returns attribute value if available" do
    assert_equal Rails.root.join("tmp/test").to_s, @model.source_path
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

  test "handle_git_error raises error if on_git_error not available" do
    error = StandardError.new("Test error")
    assert_raises(StandardError) { @model.handle_git_error(error) }
  end

  test "handle_git_error handles repository errors" do
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

  test "handles git errors with custom handler" do
    error = StandardError.new("Test error")
    @model.stubs(:on_git_error)
    @model.expects(:on_git_error).with(error)
    @model.handle_git_error(error)
  end

  test "evaluates git_backed_options in instance context" do
    test_class = Class.new(TestModel) do
      def self.has_attribute?(attr)
        false
      end

      git_backed_options(
        source_path: -> { "#{name}-path" },
        cleanup_after_push: -> { name == "cleanup-me" }
      )
    end

    model = test_class.new(name: "test")
    assert_equal "test-path", model.source_path
    assert_not model.cleanup_after_push?

    model.name = "cleanup-me"
    assert model.cleanup_after_push?
  end
end
