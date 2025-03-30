class AddPageToIngredients < ActiveRecord::Migration[8.0]
  def change
    add_reference :ingredients, :page, null: true, foreign_key: true
  end
end
