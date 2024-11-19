Rails.application.config.middleware.use OmniAuth::Builder do
  next if ENV["RAILS_BUILD"]

  credentials = Rails.application.credentials
  github_oauth_credentials = credentials.github_oauth

  provider :github,
    github_oauth_credentials.client_id,
    github_oauth_credentials.client_secret,
    scope: "public_repo"
end
