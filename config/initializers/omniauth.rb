Rails.application.config.middleware.use OmniAuth::Builder do
  if ENV["RAILS_BUILD"]
    # During asset compilation, set dummy values
    provider :github, "dummy_id", "dummy_secret", scope: "public_repo"
  else
    # Normal runtime configuration
    credentials = Rails.application.credentials
    github_oauth_credentials = credentials.github_oauth

    provider :github,
      github_oauth_credentials.client_id,
      github_oauth_credentials.client_secret,
      scope: "public_repo workflow"
  end
end
