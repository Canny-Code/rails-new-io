require "test_helper"

class GitBackedModelTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  class DummyModel
    include ActiveRecord::Callbacks
    include ActiveModel::Model
    include GitBackedModel
    include ActiveModel::Dirty

    define_callbacks :create, :update
    define_attribute_methods [ :content ]

    attr_accessor :updated_at, :updated_by, :content

    def initialize
      @content = nil
    end

    def content=(val)
      content_will_change!
      @content = val
    end

    def changed
      changes.keys
    end

    def model_name
      "DummyModel"
    end

    def identifier
      "123"
    end

    def change_description
      "Updated content"
    end

    def repo_name
      "test-repo"
    end
  end

  setup do
    @model = DummyModel.new
    @model.updated_by = users(:jane)
    @repo = mock
    @model.stubs(:repo).returns(@repo)
  end

  test "sync_to_git skips when no meaningful changes" do
    travel_to Time.current do
      @model.updated_at = Time.current
      @repo.expects(:write_model).never
      @repo.expects(:commit!).never

      @model.send(:sync_to_git)
    end
  end

  test "sync_to_git commits changes when meaningful updates exist" do
    @model.content = "new content"

    @repo.expects(:write_model).with(@model)
    @repo.expects(:commit!).with(
      "Update DummyModel 123: Updated content",
      author: users(:jane)
    )

    @model.send(:sync_to_git)
  end

  test "sync_to_git handles repo errors gracefully" do
    @model.content = "new content"

    @repo.expects(:write_model).with(@model).raises(GitRepo::GitSyncError)

    assert_raises GitRepo::GitSyncError do
      @model.send(:sync_to_git)
    end
  end
end
