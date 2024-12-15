module GitBackedModel
  extend ActiveSupport::Concern

  included do
    after_create :initial_git_commit
    after_update :sync_to_git
  end

  private

  def initial_git_commit
    repo.commit_changes(
      message: "Initial commit",
      author: commit_author
    )
  end

  def sync_to_git
    return unless should_sync_to_git?

    repo.write_model(self)
    repo.commit!(
      "Update #{model_name} #{identifier}: #{change_description}",
      author: updated_by
    )
  end

  def repo
    @repo ||= DataRepository.new(
      user: commit_author,
    )
  end

  def commit_author
    respond_to?(:user) ? user : created_by
  end

  def should_sync_to_git?
    # Only sync meaningful changes, not timestamps etc
    (changed - %w[updated_at]).any?
  end
end
