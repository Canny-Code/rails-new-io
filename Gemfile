source "https://rubygems.org"

gem "rails", "8.0.0"

gem "aasm", "~> 5.5.0"
gem "bootsnap", require: false
gem "friendly_id", "~> 5.5.1"
gem "git", "~> 2.3.2"
gem "kamal", "~> 2.3.0", require: false
gem "thruster", "~> 0.1.9", require: false
gem "mission_control-jobs", "~> 0.6.0"
gem "noticed", "~> 2.4.3"
gem "litestream", "~> 0.12.0"
gem "octokit", "~> 9.2.0"
gem "omniauth-github", github: "omniauth/omniauth-github", branch: "master"
gem "omniauth-rails_csrf_protection"
gem "pagy", "~> 9.3.1"
gem "phlex-rails", "~> 1.2.2"
gem "propshaft", "~> 1.1.0"
gem "puma", ">= 6.5.0"
gem "sentry-ruby"
gem "sentry-rails"
gem "stackprof"
gem "solid_cache", "~> 1.0.6"
gem "solid_cable", "~> 3.0.2"
gem "solid_queue", "~> 1.0.2"
gem "sqlite3", "~> 2.3.1"
gem "stimulus-rails"
gem "turbo-rails", "~> 2.0.11"
gem "vite_rails", "~> 3.0.19"

group :development do
  gem "annotaterb"
  gem "better_html", require: false
  gem "erb_lint", require: false
  gem "overcommit", require: false
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "database_cleaner-active_record"
  gem "selenium-webdriver", "~> 4.27.0"
  gem "mocha", "~> 2.6.0"
  gem "simplecov", require: false
  gem "simplecov-tailwindcss", require: false
  gem "faker"
end

group :development, :test do
  gem "brakeman", "~> 6.2.2", require: false
  gem "debug", platforms: %i[ mri ], require: "debug/prelude"
  gem "rubocop-rails-omakase", require: false
  gem "amazing_print", "~> 1.6"
  gem "minio", "~> 0.4.0"
  gem "dotenv-rails"
end
