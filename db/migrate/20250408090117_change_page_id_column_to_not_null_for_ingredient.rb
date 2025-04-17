class ChangePageIdColumnToNotNullForIngredient < ActiveRecord::Migration[8.0]
  def change
    # First, delete any ingredients without a page_id
    execute("DELETE FROM ingredients WHERE page_id IS NULL")

    # Then add the NOT NULL constraint
    change_column_null :ingredients, :page_id, false
  end
end
