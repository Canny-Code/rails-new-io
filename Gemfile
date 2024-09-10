source "https://rubygems.org"

gem "rails", github: "rails/rails", branch: "main"

gem "bootsnap", require: false
gem "kamal", "~> 1.8.3", require: false
gem "mission_control-jobs", "~> 0.3.1"
gem "litestream", "~> 0.11.2"
gem "propshaft", "~> 0.9.1"
gem "solid_cache", "~> 1.0.5"
gem "solid_queue", "~> 0.5.0"
gem "sqlite3", "~> 2.0.4"
gem "stimulus-rails"
gem "turbo-rails"
gem "puma", ">= 6.4.2"
gem "phlex-rails", "~> 1.2.1"
gem "thruster", "~> 0.1.8"
gem "vite_rails", "~> 3.0.17"
gem "tracer"

group :development do
  gem "better_html", require: false
  gem "erb_lint", require: false
  gem "overcommit", require: false
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver", "~> 4.24"
  gem "mocha", "~> 2.4.5"
  gem "simplecov", require: false
  gem "simplecov-tailwindcss", require: false
end

group :development, :test do
  gem "brakeman", "~> 6.2.1", require: false
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rubocop-rails-omakase", require: false
  gem "amazing_print", "~> 1.6"
  gem "minio", "~> 0.4.0"
  gem "dotenv-rails"
end
