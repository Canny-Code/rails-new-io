class UpdateAllForeignKeys < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :app_changes, :generated_apps
    remove_foreign_key :app_changes, :ingredients
    remove_foreign_key :app_generation_log_entries, :generated_apps
    remove_foreign_key :app_statuses, :generated_apps

    add_foreign_key :app_changes, :generated_apps, on_delete: :cascade
    add_foreign_key :app_changes, :ingredients, on_delete: :cascade
    add_foreign_key :app_generation_log_entries, :generated_apps, on_delete: :cascade
    add_foreign_key :app_statuses, :generated_apps, on_delete: :cascade
  end
end
