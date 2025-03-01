class AddSnippetsToIngredients < ActiveRecord::Migration[8.0]
  def change
    add_column :ingredients, :snippets, :json, default: []
  end
end
