class AddSubCategoryColumnToIngredients < ActiveRecord::Migration[8.0]
  def change
    add_column :ingredients, :sub_category, :string, default: "Default"
  end
end
