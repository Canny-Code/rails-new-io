class CreateAppChanges < ActiveRecord::Migration[8.0]
  def change
    create_table :app_changes do |t|
      t.references :generated_app, null: false, foreign_key: true
      t.references :ingredient, null: false, foreign_key: true
      t.json :configuration
      t.datetime :applied_at
      t.boolean :success
      t.text :error_message

      t.timestamps
    end
  end
end
