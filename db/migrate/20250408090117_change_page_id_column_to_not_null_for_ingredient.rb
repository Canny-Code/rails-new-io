class ChangePageIdColumnToNotNullForIngredient < ActiveRecord::Migration[8.0]
  def change
    # Defer foreign key checks until the end of the transaction
    execute("PRAGMA defer_foreign_keys = ON")

    # Just drop the table
    drop_table :ingredients if table_exists?(:ingredients)
  end
end
