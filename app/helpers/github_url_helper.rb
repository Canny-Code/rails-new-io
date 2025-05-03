module GithubUrlHelper
  def final_instructions(github_user_name, repo_name)
    "git@github.com:#{github_user_name}/#{repo_name}.git && cd #{repo_name} && bundle install && rails db:migrate && bin/dev"
  end
end
