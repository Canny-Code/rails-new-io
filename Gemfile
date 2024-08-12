source "https://rubygems.org"

gem "rails", "~> 7.2.0"

gem "bootsnap", require: false
gem "propshaft"
gem "sqlite3", ">= 1.4"
gem "stimulus-rails"
gem "turbo-rails"
gem "puma", ">= 5.0"
gem "redis", ">= 4.0.1"

gem "phlex-rails", "~> 1.2", ">= 1.2.1"
gem "vite_rails", "~> 3.0", ">= 3.0.17"

group :development do
  gem "better_html", require: false
  gem "erb_lint", require: false
  gem "overcommit", require: false
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "mocha"
  gem "simplecov", require: false
  gem "simplecov-tailwindcss", require: false
end

group :development, :test do
  gem "brakeman", require: false
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rubocop-rails-omakase", require: false
end
