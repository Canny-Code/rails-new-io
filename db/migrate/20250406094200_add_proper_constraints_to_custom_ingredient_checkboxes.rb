class AddProperConstraintsToCustomIngredientCheckboxes < ActiveRecord::Migration[8.0]
  def change
    # First remove any existing foreign key constraints
    remove_foreign_key :element_custom_ingredient_checkboxes, :ingredients if foreign_key_exists?(:element_custom_ingredient_checkboxes, :ingredients)

    # Add back the foreign key with ON DELETE CASCADE
    add_foreign_key :element_custom_ingredient_checkboxes, :ingredients, on_delete: :cascade

    # Ensure ingredient_id is unique and not null
    change_column_null :element_custom_ingredient_checkboxes, :ingredient_id, false
    add_index :element_custom_ingredient_checkboxes, :ingredient_id, unique: true, name: 'unique_ingredient_checkbox'
  end
end
