# Exit if we're in production
if Rails.env.production?
  puts "🚫 Don't run seeds in production!"
  exit
end

# Temporarily disable foreign key checks
ActiveRecord::Base.connection.execute('PRAGMA foreign_keys = OFF;')

puts "Cleaning database..."
# Delete all records from all tables
GeneratedApp.delete_all
AppStatus.delete_all if defined?(AppStatus)
Repository.delete_all if defined?(Repository)
User.delete_all

# Re-enable foreign key checks
ActiveRecord::Base.connection.execute('PRAGMA foreign_keys = ON;')

# Create the user
puts "Creating user..."
user = User.create!(
  provider: 'github',
  uid: '29518382',
  github_username: 'trinitytakei',
  email: 'trinitytakei@example.com',
  name: 'Trinity Takei',
  github_token: 'ghp_something123'
)

generated_apps_data = [
  {
    name: "blog",
    description: "Personal blog with markdown support",
    ruby_version: "3.2.2",
    rails_version: "7.1.2",
    selected_gems: [ "devise", "tailwindcss-rails", "redcarpet" ],
    configuration_options: {
      database: "postgresql",
      css: "tailwind",
      testing: "minitest"
    },
    github_repo_url: "https://github.com/john/blog",
    github_repo_name: "blog",
    is_public: false
  },
  {
    name: "inventory-api",
    description: "REST API for inventory management",
    ruby_version: "3.2.2",
    rails_version: "7.1.2",
    selected_gems: [ "jsonapi-serializer", "rack-cors", "rswag" ],
    configuration_options: {
      database: "postgresql",
      api_only: true,
      testing: "rspec"
    },
    github_repo_url: "https://github.com/sarah/inventory-api",
    github_repo_name: "inventory-api",
    is_public: true
  },
  {
    name: "saas",
    description: "SaaS application template",
    ruby_version: "3.2.2",
    rails_version: "7.1.2",
    selected_gems: [ "devise", "pay", "tailwindcss-rails" ],
    configuration_options: {
      database: "postgresql",
      css: "tailwind",
      testing: "rspec"
    },
    github_repo_url: "https://github.com/bob/saas",
    github_repo_name: "saas",
    is_public: false
  }
]

generated_apps_data.each do |app_data|
  generated_app = user.generated_apps.create!(app_data)
  puts "Created GeneratedApp: #{generated_app.name}"
end
