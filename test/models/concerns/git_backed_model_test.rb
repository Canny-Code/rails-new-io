require "test_helper"

class GitBackedModelTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  class TestModel
    include ActiveModel::Model
    include GitBackedModel

    attr_accessor :id, :name, :source_path, :user, :created_at, :updated_at

    def self.has_attribute?(attr)
      attr.to_s == "source_path"
    end

    def []=(attr, value)
      instance_variable_set("@#{attr}", value)
    end

    def [](attr)
      instance_variable_get("@#{attr}")
    end

    def changed
      [ "name" ]
    end

    def changes
      { "name" => [ "old", "new" ] }
    end

    def identifier
      "test-#{id}"
    end

    def change_description
      "test change"
    end

    def model_name
      "TestModel"
    end

    def updated_by
      user
    end
  end

  def setup
    @user = users(:john)
    @model = TestModel.new(
      id: 1,
      name: "test",
      source_path: Rails.root.join("tmp/test").to_s,
      user: @user,
      created_at: Time.now,
      updated_at: Time.now
    )

    # Mock DataRepository
    @repo_mock = mock("data_repository")
    @repo_mock.stubs(:write_model)
    @repo_mock.stubs(:commit_changes)
    DataRepository.stubs(:new).returns(@repo_mock)
  end

  test "includes necessary methods" do
    assert_respond_to @model, :initial_git_commit
    assert_respond_to @model, :sync_to_git
    assert_respond_to @model, :repo
    assert_respond_to @model, :commit_author
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
    repo.expects(:initialize_repository).with(repo_name: "test")
    repo.expects(:push_app_files).with(source_path: @model.source_path)
    @model.stubs(:repo).returns(repo)

    @model.initial_git_commit
  end

  test "sync_to_git pushes files" do
    repo = mock("repo")
    repo.expects(:push_app_files).with(source_path: @model.source_path)
    @model.stubs(:repo).returns(repo)

    @model.sync_to_git
  end

  test "repo returns nil if should_create_repository? is false" do
    @model.stubs(:should_create_repository?).returns(false)
    assert_nil @model.repo
  end

  test "repo returns AppRepositoryService for GeneratedApp" do
    app = GeneratedApp.new
    app.stubs(:should_create_repository?).returns(true)
    app.stubs(:commit_author).returns(@user)
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
    @model.source_path = nil
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
    TestModel.git_backed_options(source_path: "test")
    assert_equal "test", @model.source_path
  end

  test "source_path executes proc if configured" do
    TestModel.git_backed_options(source_path: -> { "test" })
    assert_equal "test", @model.source_path
  end

  test "source_path returns attribute value if available" do
    assert_equal Rails.root.join("tmp/test").to_s, @model.source_path
  end

  test "repo_name returns name if available" do
    assert_equal "test", @model.repo_name
  end

  test "repo_name returns fallback if name not available" do
    @model.name = nil
    assert_equal "test_model-1", @model.repo_name
  end

  test "commit_author returns user if available" do
    assert_equal @model.user, @model.commit_author
  end

  test "commit_author returns created_by if user not available" do
    @model.user = nil
    @model.stubs(:created_by).returns("creator")
    assert_equal "creator", @model.commit_author
  end

  test "updated_by returns user if available" do
    assert_equal @model.user, @model.updated_by
  end

  test "updated_by returns updated_by if user not available" do
    @model.user = nil
    @model.stubs(:updated_by).returns("updater")
    assert_equal "updater", @model.updated_by
  end

  test "identifier returns name if available" do
    assert_equal "test", @model.identifier
  end

  test "identifier returns id if name not available" do
    @model.name = nil
    assert_equal 1, @model.identifier
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
    app = GeneratedApp.new
    app.stubs(:should_create_repository?).returns(true)
    app.stubs(:commit_author).returns(@user)
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

  test "uses user as commit author when available" do
    assert_equal @user, @model.send(:commit_author)
  end

  test "raises error when no commit author available" do
    @model.user = nil
    assert_raises(StandardError) do
      @model.send(:commit_author)
    end
  end

  test "evaluates git_backed_options in instance context" do
    class TestModelWithDynamicOptions < TestModel
      git_backed_options(
        source_path: -> { "#{name}-path" },
        cleanup_after_push: -> { name == "cleanup-me" }
      )
    end

    model = TestModelWithDynamicOptions.new(name: "test")
    assert_equal "test-path", model.send(:source_path)
    assert_not model.send(:cleanup_after_push?)

    model.name = "cleanup-me"
    assert model.send(:cleanup_after_push?)
  end
end
