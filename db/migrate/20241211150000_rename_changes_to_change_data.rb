class RenameChangesToChangeData < ActiveRecord::Migration[8.0]
  def change
    rename_column :recipe_changes, :changes, :change_data
    rename_column :ingredient_changes, :changes, :change_data
  end
end
