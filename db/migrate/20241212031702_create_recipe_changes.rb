class CreateRecipeChanges < ActiveRecord::Migration[8.0]
  def change
    create_table :recipe_changes do |t|
      t.belongs_to :recipe, null: false, foreign_key: { on_delete: :cascade }
      t.belongs_to :ingredient, foreign_key: true  # optional, for ingredient-related changes
      t.string :change_type, null: false  # add_ingredient, remove_ingredient, reorder, config
      t.json :changes, null: false  # Store the actual changes
      t.text :description
      t.datetime :applied_at
      t.boolean :success
      t.text :error_message

      t.timestamps
    end
  end
end
