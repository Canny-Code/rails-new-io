class AddUniqueConstraintToElementCustomIngredientCheckboxes < ActiveRecord::Migration[8.0]
  def change
    add_index :element_custom_ingredient_checkboxes, :ingredient_id, unique: true, name: 'index_element_custom_ingredient_checkboxes_unique_ingredient'
  end
end
