source "https://rubygems.org"

gem "rails", "8.0.0.rc1"

gem "bootsnap", require: false
gem "friendly_id", "~> 5.5.1"
gem "kamal", "~> 2.2.2", require: false
gem "mission_control-jobs", "~> 0.3.3"
gem "litestream", "~> 0.11.2"
gem "propshaft", "~> 1.1.0"
gem "solid_cache", "~> 1.0.6"
gem "solid_queue", "~> 1.0.0"
gem "sqlite3", "~> 2.1.0"
gem "stimulus-rails"
gem "turbo-rails", "~> 2.0.11"
gem "puma", ">= 6.4.3"
gem "phlex-rails", "~> 1.2.1"
gem "thruster", "~> 0.1.8"
gem "vite_rails", "~> 3.0.18"

group :development do
  gem "annotaterb"
  gem "better_html", require: false
  gem "erb_lint", require: false
  gem "overcommit", require: false
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver", "~> 4.25.0"
  gem "mocha", "~> 2.4.5"
  gem "simplecov", require: false
  gem "simplecov-tailwindcss", require: false
end

group :development, :test do
  gem "brakeman", "~> 6.2.2", require: false
  gem "debug", platforms: %i[ mri ], require: "debug/prelude"
  gem "rubocop-rails-omakase", require: false
  gem "amazing_print", "~> 1.6"
  gem "minio", "~> 0.4.0"
  gem "dotenv-rails"
end
