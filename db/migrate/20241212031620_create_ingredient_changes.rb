class CreateIngredientChanges < ActiveRecord::Migration[8.0]
  def change
    create_table :ingredient_changes do |t|
      t.belongs_to :ingredient, null: false, foreign_key: { on_delete: :cascade }
      t.string :change_type, null: false
      t.json :changes, null: false
      t.text :description
      t.datetime :applied_at
      t.boolean :success
      t.text :error_message

      t.timestamps
    end
  end
end
