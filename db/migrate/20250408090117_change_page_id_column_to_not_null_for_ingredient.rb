class ChangePageIdColumnToNotNullForIngredient < ActiveRecord::Migration[8.0]
  def change
    # Defer foreign key checks until the end of the transaction
    execute("PRAGMA defer_foreign_keys = ON")

    # Drop and recreate the table
    drop_table :ingredients if table_exists?(:ingredients)

    create_table :ingredients do |t|
      t.string :name, null: false
      t.text :description
      t.text :template_content, null: false
      t.text :conflicts_with
      t.text :requires
      t.text :configures_with
      t.integer :created_by_id, null: false
      t.string :category
      t.json :snippets, default: []
      t.integer :page_id, null: false
      t.string :sub_category, default: "Default"
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_index :ingredients, :created_by_id
    add_index :ingredients, [ :name, :created_by_id, :page_id, :category, :sub_category ], unique: true, name: "index_ingredients_on_name_scope"
    add_index :ingredients, :page_id
  end
end
