# == Schema Information
#
# Table name: commits
#
#  id             :integer          not null, primary key
#  message        :text             not null
#  parent_sha     :string
#  sha            :string           not null
#  state_snapshot :json             not null
#  versioned_type :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  author_id      :integer          not null
#  versioned_id   :integer          not null
#
# Indexes
#
#  index_commits_on_author_id  (author_id)
#  index_commits_on_sha        (sha) UNIQUE
#  index_commits_on_versioned  (versioned_type,versioned_id)
#
# Foreign Keys
#
#  author_id  (author_id => users.id)
#
require "test_helper"

class CommitTest < ActiveSupport::TestCase
  include Mocha::API

  setup do
    User.any_instance.stubs(:github_token).returns("fake-token")
    @commit = commits(:blog_initial)
    @commit_with_parent = commits(:blog_second)
    @user = users(:jane)
    @generated_app = generated_apps(:blog_app)
  end

  test "valid commit" do
    assert @commit.valid?
  end

  test "belongs to versioned" do
    assert_equal @generated_app, @commit.versioned
  end

  test "belongs to author" do
    assert_equal @user, @commit.author
  end

  test "requires sha" do
    @commit.sha = nil
    assert_not @commit.valid?
    assert_includes @commit.errors[:sha], "can't be blank"
  end

  test "requires unique sha" do
    duplicate = @commit.dup
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:sha], "has already been taken"
  end

  test "requires message" do
    @commit.message = nil
    assert_not @commit.valid?
    assert_includes @commit.errors[:message], "can't be blank"
  end

  test "requires state_snapshot" do
    @commit.state_snapshot = nil
    assert_not @commit.valid?
    assert_includes @commit.errors[:state_snapshot], "can't be blank"
  end

  test "generates sha before create" do
    new_commit = Commit.new(
      message: "New commit",
      state_snapshot: { "name": "new-app" },
      versioned: @generated_app,
      author: @user
    )

    assert_nil new_commit.sha
    new_commit.send(:generate_sha)
    assert new_commit.valid?
    assert_not_nil new_commit.sha
    assert_match(/\A[0-9a-f]{40}\z/, new_commit.sha)
    new_commit.save!
  end

  test "finds parent commit" do
    assert_nil @commit.parent
    assert_equal @commit, @commit_with_parent.parent
  end

  test "returns nil for parent when parent_sha is blank" do
    @commit_with_parent.parent_sha = nil
    assert_nil @commit_with_parent.parent
  end

  test "restore! updates versioned record with state_snapshot" do
    @commit.restore!
    @generated_app.reload

    assert_equal @commit.state_snapshot["name"], @generated_app.name
  end
end
