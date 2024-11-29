class AddEntryTypeToAppGenerationLogEntries < ActiveRecord::Migration[7.1]
  def change
    add_column :app_generation_log_entries, :entry_type, :string
    add_index :app_generation_log_entries, :entry_type
  end
end
