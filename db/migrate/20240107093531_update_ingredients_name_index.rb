class UpdateIngredientsNameIndex < ActiveRecord::Migration[7.1]
  def change
    remove_index :ingredients, :name
    add_index :ingredients, [ :name, :created_by_id ], unique: true
  end
end
