class CreateIngredients < ActiveRecord::Migration[8.0]
  def change
    create_table :ingredients do |t|
      t.string :name, null: false
      t.text :description
      t.text :template_content, null: false
      t.text :conflicts_with
      t.text :requires
      t.text :configures_with
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :category

      t.timestamps

      t.index :name, unique: true
    end
  end
end
