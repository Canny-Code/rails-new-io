module GitBackedModel
  extend ActiveSupport::Concern

  included do
    # Remove the callbacks - we'll call these methods explicitly
    # after_commit :initial_git_commit, on: :create
    # after_commit :sync_to_git, on: :update
  end

  class_methods do
    def git_backed_options(options = {})
      @git_backed_options = options
    end

    def get_git_backed_options
      @git_backed_options || {}
    end
  end

  def initial_git_commit
    return if @performing_git_operation
    return unless should_create_repository?

    @performing_git_operation = true

    begin
      repo.initialize_repository(repo_name: repo_name)
      repo.push_app_files(source_path: source_path) if source_path.present?
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
      repo.push_app_files(source_path: source_path)
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
        DataRepositoryService.new(user: commit_author)
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
    options = self.class.get_git_backed_options
    cleanup_option = options[:cleanup_after_push]

    case cleanup_option
    when Proc
      instance_exec(&cleanup_option)
    when nil
      false
    else
      cleanup_option
    end
  end

  def source_path
    return @source_path if defined?(@source_path)

    options = self.class.get_git_backed_options
    path_option = options[:source_path]

    @source_path = case path_option
    when Proc
      instance_exec(&path_option)
    when nil
      # Try the source_path attribute first (database column)
      # Then try source_path_attribute (dynamic method)
      if has_attribute?(:source_path)
        self[:source_path]
      elsif respond_to?(:source_path_attribute)
        source_path_attribute
      end
    else
      path_option
    end

    @source_path
  end

  def repo_name
    respond_to?(:name) ? name : "#{self.class.name.underscore}-#{id}"
  end

  def commit_author
    respond_to?(:user) ? user : created_by
  end

  def updated_by
    respond_to?(:user) ? user : updated_by
  end

  def identifier
    respond_to?(:name) ? name : id
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
