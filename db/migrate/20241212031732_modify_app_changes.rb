class ModifyAppChanges < ActiveRecord::Migration[8.0]
  def change
    remove_reference :app_changes, :ingredient
    add_reference :app_changes, :recipe_change, foreign_key: { on_delete: :cascade }
  end
end
