module GitBackedModel
  extend ActiveSupport::Concern

  def initial_git_commit
    return if @performing_git_operation
    return unless should_create_repository?

    @performing_git_operation = true

    begin
      repo.initialize_repository
      repo.commit_changes(
        message: "Initial commit",
        tree_items: []
      ) if source_path.present?
    rescue StandardError => e
      handle_git_error(e)
    ensure
      @performing_git_operation = false
    end
  end

  def sync_to_git
    return unless should_sync_to_git?
    return if @performing_git_operation
    return unless should_create_repository?

    @performing_git_operation = true

    begin
      repo.commit_changes(
        message: "Update #{model_name.singular}",
        tree_items: []
      )
    rescue StandardError => e
      handle_git_error(e)
    ensure
      @performing_git_operation = false
    end
  end

  def repo
    return nil unless should_create_repository?

    @repo ||= begin
      case self
      when GeneratedApp
        AppRepositoryService.new(self)
      else
        DataRepositoryService.new(user: created_by)
      end
    end
  end

  def should_sync_to_git?
    # Only sync if there are changes other than timestamps
    (changed - %w[created_at updated_at]).any?
  end

  def should_create_repository?
    path = source_path
    return false if path.blank?
    return File.directory?(path) if Rails.env.test?

    true
  end

  def cleanup_after_push?
    false
  end

  def source_path
    return @source_path if defined?(@source_path)

    @source_path = if has_attribute?(:source_path)
      self[:source_path]
    elsif respond_to?(:source_path_attribute)
      source_path_attribute
    end
  end

  def repo_name
    name
  end

  def identifier
    name
  end

  def change_description
    changes.except("created_at", "updated_at").map do |attr, (old_val, new_val)|
      "#{attr}: #{old_val} -> #{new_val}"
    end.join(", ")
  end

  def handle_git_error(error)
    if respond_to?(:on_git_error)
      on_git_error(error)
    else
      raise error
    end
  end
end
