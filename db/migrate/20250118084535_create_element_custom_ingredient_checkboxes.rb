class CreateElementCustomIngredientCheckboxes < ActiveRecord::Migration[7.1]
  def change
    create_table :element_custom_ingredient_checkboxes do |t|
      t.boolean :checked
      t.boolean :default
      t.references :ingredient, null: false, foreign_key: true

      t.timestamps
    end
  end
end
