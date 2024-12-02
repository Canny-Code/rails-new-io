class GithubCodePushJob < ApplicationJob
  retry_on GithubCodePushService::GitError, wait: 5.seconds, attempts: 5

  def perform(user_id, repository_name, source_path)
    user = User.find(user_id)
    service = GithubCodePushService.new(user, repository_name, source_path)
    service.push
  end
end
