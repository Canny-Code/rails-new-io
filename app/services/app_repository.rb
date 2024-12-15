class AppRepository < GitRepo
  def initialize(user:, app_name:)
    super(user: user, repo_name: app_name)
    ensure_app_repo_exists
  end

  # App repo specific methods...
end
