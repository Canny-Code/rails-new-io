class DropIngredientChanges < ActiveRecord::Migration[8.0]
  def change
    drop_table :ingredient_changes
  end
end
