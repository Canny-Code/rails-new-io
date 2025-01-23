class GithubCodePushJob < ApplicationJob
  queue_as :default

  def perform(user_id, repo_name, source_path, cleanup_after_push = false)
    user = User.find(user_id)
    service = AppRepositoryService.new(user)

    service.initialize_repository(repo_name: repo_name)
    service.push_app_files(source_path: source_path)

    FileUtils.rm_rf(source_path) if cleanup_after_push
  end
end
