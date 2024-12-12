require_relative "../../test/support/coverage_helper"
include CoverageHelper

unless skip_coverage?
  require "simplecov"
  require "simplecov-tailwindcss"
end

namespace :test do
  desc "Run all tests and collate coverage"
  task run_all_with_coverage: [
    "test:delete_previous_coverage",
    "test:prepare",
    "test:run_non_system",
    "test:run_system",
    "test:collate_coverage"
  ]

  task :delete_previous_coverage do
    FileUtils.rm_rf(SimpleCov.coverage_dir)
  end

  task :run_non_system do
    system "rails test"
  end

  task :run_system do
    system "rails test:system"
  end

  task :collate_coverage do
    SimpleCov.collate Dir["#{SimpleCov.coverage_dir}/**/.resultset.json"] do
      command_name "All Tests"
      enable_coverage :branch

      SimpleCov.formatter = SimpleCov::Formatter::TailwindFormatter

      add_group "Models", "app/models"
      add_group "Controllers", "app/controllers"
      add_group "Helpers", "app/helpers"
      add_group "Jobs", "app/jobs"
      add_group "Mailers", "app/mailers"
      add_group "Notifiers", "app/notifiers"
      add_group "Utils", "app/utils"
    end

    puts "\n\033[32mDone! You can view the coverage report by running `open coverage/index.html?o=1`.\033[0m"
    puts "Or click: file:///Users/mia/workspace/rails/rails-new-io/coverage/index.html?o=1"
  end
end
