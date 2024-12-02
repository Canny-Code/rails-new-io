module GithubUrlHelper
  def github_ssh_url(github_user_name, repo_name)
    "git@github.com:#{github_user_name}/#{repo_name}.git && cd #{repo_name}"
  end
end
