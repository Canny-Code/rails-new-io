class ChangePageIdColumnToNotNullForIngredient < ActiveRecord::Migration[8.0]
  def change
    change_column_null :ingredients, :page_id, false
  end
end
