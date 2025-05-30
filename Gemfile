source "https://rubygems.org"

gem "rails", "8.0.2"

gem "acidic_job", "= 1.0.0.rc1"
gem "aasm", "~> 5.5.0"
gem "amazing_print", "~> 1.7.2"
gem "aws-sdk-s3", "1.170", require: false
gem "aws-sdk-core", "3.211"
gem "bootsnap", require: false
gem "faraday-retry", "~> 2.3.1"
gem "friendly_id", "~> 5.5.1"
gem "kamal", "~> 2.5.3", require: false
gem "thruster", "~> 0.1.13", require: false
gem "mission_control-jobs", "~> 1.0.2"
gem "noticed", "~> 2.6.1"
gem "litestream", "~> 0.12.0"
gem "octokit", "~> 10.0.0"
gem "omniauth-github", github: "omniauth/omniauth-github", branch: "master"
gem "omniauth-rails_csrf_protection"
gem "pagy", "~> 9.3.4"
gem "phlex-rails", "~> 1.2.2"
gem "propshaft", "~> 1.1.0"
gem "puma", ">= 6.6.0"
gem "sentry-ruby", "~> 5.23.0"
gem "sentry-rails", "~> 5.23.0"
gem "stackprof", "~> 0.2.27"
gem "solid_cache", "~> 1.0.7"
gem "solid_cable", "~> 3.0.7"
gem "solid_queue", "~> 1.1.5"
gem "sqlite3", "~> 2.6.0"
gem "stimulus-rails"
gem "turbo-rails", "~> 2.0.13"
gem "vite_rails", "~> 3.0.19"
gem "redcarpet", "~> 3.6.1"

group :development do
  gem "aasm-diagram", "~> 0.1.3"
  gem "annotaterb"
  gem "better_html", require: false
  gem "erb_lint", "~> 0.9.0", require: false
  gem "overcommit", require: false
  gem "rails-erd", "~> 1.7.2"
end

group :test do
  gem "capybara"
  gem "capybara-lockstep", "~> 2.2.3"
  gem "minitest-difftastic", "~> 0.2.1"
  gem "database_cleaner-active_record"
  gem "selenium-webdriver", "~> 4.31.0"
  gem "mocha", "~> 2.7.1"
end

group :development, :test do
  gem "brakeman", "~> 7.0.2", require: false
  gem "debug", "~> 1.10.0", platforms: %i[ mri ], require: "debug/prelude"
  gem "rubocop-rails-omakase", require: false
  gem "minio", "~> 0.4.0"
  gem "dotenv-rails", "~> 3.1.8"
  gem "simplecov", require: false
  gem "simplecov-tailwindcss", require: false
  gem "faker"
end
