class ChangePageIdColumnToNotNullForIngredient < ActiveRecord::Migration[8.0]
  def change
    # First delete any dependent records
    execute("DELETE FROM element_custom_ingredient_checkboxes WHERE ingredient_id IN (SELECT id FROM ingredients WHERE page_id IS NULL)")

    # Then delete ingredients without page_id
    execute("DELETE FROM ingredients WHERE page_id IS NULL")

    # Finally add the NOT NULL constraint
    change_column_null :ingredients, :page_id, false
  end
end
