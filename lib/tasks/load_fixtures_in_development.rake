namespace :db do
  task load_fixtures_in_development: :environment do
    if Rails.env.development?
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = OFF;") if ActiveRecord::Base.connection.adapter_name == "SQLite"

        fixtures_to_load = %w[
          pages
          groups
          sub_groups
          element/radio_buttons
          element/checkboxes
          element/text_fields
          elements
        ]

        Rake::Task["db:fixtures:load"].invoke(*fixtures_to_load)

        # Run callbacks on all elements
        Element.all.each(&:save)

        ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = ON;") if ActiveRecord::Base.connection.adapter_name == "SQLite"
      end
    end
  end

  Rake::Task["db:seed"].enhance([ "db:load_fixtures_in_development" ])
end
