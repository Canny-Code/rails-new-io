class ChangePageIdColumnToNotNullForIngredient < ActiveRecord::Migration[8.0]
  def change
    disable_referential_integrity do
      drop_table :ingredients if table_exists?(:ingredients)
    end
  end
end
