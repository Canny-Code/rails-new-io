class UpdateIngredientUniquenessConstraint < ActiveRecord::Migration[7.1]
  def change
    remove_index :ingredients, name: "index_ingredients_on_name_and_created_by_id"
    add_index :ingredients, [ :name, :created_by_id, :page_id, :category ], unique: true, name: "index_ingredients_on_name_scope"
  end
end
