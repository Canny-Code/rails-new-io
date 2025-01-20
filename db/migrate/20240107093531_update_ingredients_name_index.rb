class UpdateIngredientsNameIndex < ActiveRecord::Migration[7.1]
  def change
    if index_exists?(:ingredients, :name)
      remove_index :ingredients, :name
    end
    add_index :ingredients, [ :name, :created_by_id ], unique: true
  end
end
