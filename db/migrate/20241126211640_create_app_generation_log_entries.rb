class CreateAppGenerationLogEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :app_generation_log_entries do |t|
      t.references :generated_app, null: false, foreign_key: true
      t.string :level, null: false
      t.string :phase, null: false
      t.text :message, null: false
      t.json :metadata

      t.timestamps
    end

    add_index :app_generation_log_entries, [ :generated_app_id, :created_at ]
  end
end
