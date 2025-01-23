require "test_helper"

class GitBackedModelTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  class TestModel < ApplicationRecord
    include GitBackedModel
    self.table_name = "generated_apps" # Use an existing table for testing

    belongs_to :user

    git_backed_options(
      source_path: -> { "test/path" },
      cleanup_after_push: -> { true }
    )

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
      name: "test-model",
      user: @user,
      ruby_version: "3.2.0",
      rails_version: "7.1.0"
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

  test "configures git_backed_options" do
    options = TestModel.get_git_backed_options
    assert_equal "test/path", @model.send(:source_path)
    assert @model.send(:cleanup_after_push?)
  end

  test "performs initial git commit on create" do
    @repo_mock.expects(:write_model).with(@model)
    @repo_mock.expects(:commit_changes).with(
      message: "Initial commit",
      author: @user
    )

    @model.save!
  end

  test "syncs to git on update when there are changes" do
    @model.save!

    @repo_mock.expects(:write_model).with(@model)
    @repo_mock.expects(:commit_changes).with(
      message: "Update TestModel test-#{@model.id}: test change",
      author: @user
    )

    @model.update!(name: "new-name")
  end

  test "does not sync to git when only timestamps change" do
    @model.save!

    @repo_mock.expects(:write_model).never
    @repo_mock.expects(:commit_changes).never

    @model.touch
  end

  test "uses correct repository class for GeneratedApp" do
    app = generated_apps(:blog_app)
    repo = app.send(:repo)
    assert_instance_of AppRepository, repo
  end

  test "uses DataRepository for other models" do
    repo = @model.send(:repo)
    assert_instance_of DataRepository, repo
  end

  test "handles git errors with custom handler" do
    error = GitRepo::Error.new("Test error")
    @repo_mock.stubs(:write_model).raises(error)

    def @model.on_git_error(error)
      raise "Custom error: #{error.message}"
    end

    error = assert_raises(RuntimeError) do
      @model.save!
    end

    assert_equal "Custom error: Test error", error.message
  end

  test "handles git errors without custom handler" do
    error = GitRepo::Error.new("Test error")
    @repo_mock.stubs(:write_model).raises(error)

    error = assert_raises(GitRepo::Error) do
      @model.save!
    end

    assert_equal "Test error", error.message
  end

  test "uses user as commit author when available" do
    assert_equal @user, @model.send(:commit_author)
  end

  test "raises error when no commit author available" do
    @model.user = nil
    assert_raises(GitRepo::Error) do
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
