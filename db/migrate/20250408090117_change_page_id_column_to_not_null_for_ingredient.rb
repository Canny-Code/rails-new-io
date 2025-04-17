class ChangePageIdColumnToNotNullForIngredient < ActiveRecord::Migration[8.0]
  def change
    # First drop dependent tables
    drop_table :element_custom_ingredient_checkboxes if table_exists?(:element_custom_ingredient_checkboxes)

    # Then drop the ingredients table
    drop_table :ingredients if table_exists?(:ingredients)

    # Recreate ingredients with the correct constraints
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

    # Recreate dependent tables
    create_table :element_custom_ingredient_checkboxes do |t|
      t.boolean :checked
      t.boolean :default
      t.integer :ingredient_id, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_index :element_custom_ingredient_checkboxes, :ingredient_id
    add_index :element_custom_ingredient_checkboxes, :ingredient_id, unique: true, name: "index_element_custom_ingredient_checkboxes_unique_ingredient"
  end
end
