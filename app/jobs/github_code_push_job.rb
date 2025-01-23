class GithubCodePushJob < ApplicationJob
  queue_as :default

  def perform(user_id, repo_name, source_path, cleanup_after_push = false)
    user = User.find(user_id)

    repo = GitRepo.new(
      user: user,
      repo_name: repo_name,
      source_path: source_path,
      cleanup_after_push: cleanup_after_push
    )

    repo.commit_changes(
      message: "Update repository",
      author: user
    )
  end
end
