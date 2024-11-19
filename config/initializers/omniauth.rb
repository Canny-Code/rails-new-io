Rails.application.config.middleware.use OmniAuth::Builder do
  github_oauth_credentials = Rails.application.credentials.github_oauth

  provider :github,
    github_oauth_credentials.client_id,
    github_oauth_credentials.client_secret,
    scope: "public_repo"
end
