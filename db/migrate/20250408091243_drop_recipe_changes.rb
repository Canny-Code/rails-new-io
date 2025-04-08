class DropRecipeChanges < ActiveRecord::Migration[8.0]
  def change
    drop_table :recipe_changes
  end
end
