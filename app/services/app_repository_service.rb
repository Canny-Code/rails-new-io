# app/services/app_repository_service.rb
class AppRepositoryService < GithubRepositoryService
  attr_reader :generated_app

  def initialize(generated_app)
    @generated_app = generated_app
    super(
      user: generated_app.user,
      logger: AppGeneration::Logger.new(generated_app)
    )
  end

  def initialize_repository
    generated_app.create_github_repo!

    repo_name = generated_app.name

    response = create_repository(
      repo_name: repo_name,
      auto_init: false # We'll initialize with our own structure
    )

    generated_app.update!(
      github_repo_name: repo_name,
      github_repo_url: response.html_url
    )

    response
  end

  def push_app_files(source_path:)
    return unless File.directory?(source_path)

    tree_items = []

    # Add README
    tree_items << {
      path: "README.md",
      mode: "100644",
      type: "blob",
      content: readme_content
    }

    # Add all files from source directory
    Dir.glob("#{source_path}/**/*", File::FNM_DOTMATCH).each do |file_path|
      next if File.directory?(file_path)
      next if file_path.end_with?("/.") || file_path.end_with?("/..")

      relative_path = file_path.sub("#{source_path}/", "")
      content = File.read(file_path)

      tree_items << {
        path: relative_path,
        mode: "100644",
        type: "blob",
        content: content
      }
    end

    commit_changes(
      message: "Initial commit",
      tree_items: tree_items
    )
  end

  def commit_changes(message:, tree_items:)
    super(
      repo_name: generated_app.github_repo_name,
      message: message,
      tree_items: tree_items
    )
  end

  private

  def readme_content
    "# #{generated_app.name}\n\nCreated via railsnew.io"
  end
end
