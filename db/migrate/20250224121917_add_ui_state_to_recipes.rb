class AddUiStateToRecipes < ActiveRecord::Migration[8.0]
  def change
    add_column :recipes, :ui_state, :json, default: {}
  end
end
