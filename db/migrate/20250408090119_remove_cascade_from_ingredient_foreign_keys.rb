class RemoveCascadeFromIngredientForeignKeys < ActiveRecord::Migration[8.0]
  def change
    # Remove the existing foreign key with cascade
    remove_foreign_key :element_custom_ingredient_checkboxes, :ingredients

    # Add it back without cascade
    add_foreign_key :element_custom_ingredient_checkboxes, :ingredients
  end
end
