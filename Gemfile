source "https://rubygems.org"

gem "rails", "~> 7.2.0.beta2"

gem "bootsnap", require: false
gem "cssbundling-rails"
gem "jsbundling-rails"
gem "propshaft"
gem "sqlite3", ">= 1.4"
gem "stimulus-rails"
gem "turbo-rails"
gem "puma", ">= 5.0"
gem "redis", ">= 4.0.1"

group :development do
  gem "better_html", require: false
  gem "erb_lint", require: false
  gem "overcommit", require: false
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end

group :development, :test do
  gem "brakeman", require: false
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rubocop-rails-omakase", require: false
end
