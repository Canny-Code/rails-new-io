class ChangeIngredientsNameScopeIndex < ActiveRecord::Migration[8.0]
  def change
    remove_index :ingredients, name: "index_ingredients_on_name_scope"
    add_index :ingredients, [ :name, :created_by_id, :page_id, :category, :sub_category ], unique: true, name: "index_ingredients_on_name_scope"
  end
end
