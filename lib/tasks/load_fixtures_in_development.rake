namespace :db do
  Rake::Task["seed"].enhance [ "db:load_fixtures_in_development" ]

  task :load_fixtures_in_development do
    Rake::Task["db:fixtures:load"].invoke if Rails.env.development?
  end
end
