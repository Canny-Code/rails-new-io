class ChangePageIdColumnToNotNullForIngredient < ActiveRecord::Migration[8.0]
  def change
    # First remove the foreign key constraint
    remove_foreign_key :ingredients, :pages

    # Then delete ingredients without page_id
    execute("DELETE FROM ingredients WHERE page_id IS NULL")

    # Add the NOT NULL constraint
    change_column_null :ingredients, :page_id, false

    # Finally add back the foreign key constraint
    add_foreign_key :ingredients, :pages
  end
end
