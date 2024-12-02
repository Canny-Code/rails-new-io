class CreateGeneratedApps < ActiveRecord::Migration[7.0]
  def change
    create_table :generated_apps do |t|
      # Basic info
      t.string :name, null: false
      t.text :description

      # User association
      t.references :user, null: false, foreign_key: true

      # Generation configuration
      t.string :ruby_version, null: false
      t.string :rails_version, null: false
      t.json :selected_gems, default: [], null: false
      t.json :configuration_options, default: {}, null: false

      # GitHub details
      t.string :github_repo_url
      t.string :github_repo_name

      # Build info
      t.string :build_log_url
      t.datetime :last_build_at
      t.boolean :is_public, default: true

      t.timestamps
    end

    add_index :generated_apps, :name
    add_index :generated_apps, :github_repo_url, unique: true
    add_index :generated_apps, [ :user_id, :name ], unique: true
  end
end
