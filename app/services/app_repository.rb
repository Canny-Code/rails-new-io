class AppRepository < GitRepo
  def initialize(user:, app_name:, source_path: nil, cleanup_after_push: false)
    super(
      user: user,
      repo_name: app_name,
      source_path: source_path,
      cleanup_after_push: cleanup_after_push
    )
  end

  def write_model(model)
    ensure_fresh_repo

    case model
    when GeneratedApp
      write_generated_app(model)
    else
      raise ArgumentError, "Unsupported model type: #{model.class}"
    end
  end

  protected

  def ensure_committable_state
    File.write(File.join(repo_path, "README.md"), readme_content)
  end

  private

  def write_generated_app(app)
    # Copy all files from source_path to repo_path
    FileUtils.cp_r(Dir.glob("#{app.source_path}/*"), repo_path)
  end

  def readme_content
    "# #{repo_name}\nCreated via railsnew.io"
  end

  def repository_description
    "Rails application created via railsnew.io"
  end
end
