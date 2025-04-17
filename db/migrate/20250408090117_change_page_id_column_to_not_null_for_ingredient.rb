class ChangePageIdColumnToNotNullForIngredient < ActiveRecord::Migration[8.0]
  def change
    # Disable foreign key checks
    execute("PRAGMA foreign_keys = OFF")

    # Delete ingredients without page_id
    execute("DELETE FROM ingredients WHERE page_id IS NULL")

    # Re-enable foreign key checks
    execute("PRAGMA foreign_keys = ON")

    # Add the NOT NULL constraint
    change_column_null :ingredients, :page_id, false
  end
end
