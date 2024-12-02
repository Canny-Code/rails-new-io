class CreateAppStatuses < ActiveRecord::Migration[7.0]
  def change
    create_table :app_statuses do |t|
      t.references :generated_app, null: false, foreign_key: true
      t.string :status, null: false
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message
      t.json :status_history, default: []

      t.timestamps
    end

    add_index :app_statuses, :status
  end
end
