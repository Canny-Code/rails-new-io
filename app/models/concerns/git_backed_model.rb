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

  # Make these methods public so they can be called by the job
  def initial_git_commit
    puts "GitBackedModel#initial_git_commit called"
    return if @performing_git_operation
    puts "GitBackedModel#initial_git_commit not already performing operation"
    return unless should_create_repository?
    puts "GitBackedModel#initial_git_commit should create repository"
    @performing_git_operation = true

    begin
      repo.write_model(self)
      repo.commit_changes(
        message: "Initial commit",
        author: commit_author
      )
    rescue StandardError => e
      handle_git_error(e)
    ensure
      @performing_git_operation = false
    end
  end

  def sync_to_git
    puts "GitBackedModel#sync_to_git called"
    return unless should_sync_to_git?
    puts "GitBackedModel#sync_to_git should sync"
    return if @performing_git_operation
    puts "GitBackedModel#sync_to_git not already performing operation"
    return unless should_create_repository?
    puts "GitBackedModel#sync_to_git should create repository"
    @performing_git_operation = true

    begin
      repo.write_model(self)
      repo.commit_changes(
        message: "Update #{model_name} #{identifier}: #{change_description}",
        author: updated_by
      )
    rescue StandardError => e
      handle_git_error(e)
    ensure
      @performing_git_operation = false
    end
  end

  def repo
    puts "GitBackedModel#repo called"
    return nil unless should_create_repository?
    puts "GitBackedModel#repo should create repository"

    @repo ||= begin
      case self
      when GeneratedApp
        puts "GitBackedModel#repo creating AppRepository"
        AppRepository.new(
          user: commit_author,
          app_name: name,
          source_path: source_path,
          cleanup_after_push: cleanup_after_push?
        )
      else
        puts "GitBackedModel#repo creating DataRepository"
        DataRepository.new(
          user: commit_author,
          source_path: source_path,
          cleanup_after_push: cleanup_after_push?
        )
      end
    end
  end

  def should_sync_to_git?
    # Only sync if there are changes other than timestamps
    (changed - %w[created_at updated_at]).any?
  end

  def should_create_repository?
    # Don't create repository if source_path is not set
    path = source_path
    puts "GitBackedModel#should_create_repository? source_path: #{path.inspect}"
    return false if path.blank?

    # In test environment, only create if source_path exists
    if Rails.env.test?
      exists = File.directory?(path)
      puts "GitBackedModel#should_create_repository? directory exists? #{exists}"
      return exists
    end

    # In other environments, always create if source_path is set
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
        puts "GitBackedModel#source_path: Found source_path column, value: #{self[:source_path].inspect}"
        self[:source_path]
      elsif respond_to?(:source_path_attribute)
        puts "GitBackedModel#source_path: Using source_path_attribute"
        source_path_attribute
      end
    else
      path_option
    end

    puts "GitBackedModel#source_path: Final value: #{@source_path.inspect}"
    @source_path
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
