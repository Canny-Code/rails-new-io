class CreateRecipeIngredients < ActiveRecord::Migration[8.0]
  def change
    create_table :recipe_ingredients do |t|
      t.references :recipe, null: false, foreign_key: true
      t.references :ingredient, null: false, foreign_key: true
      t.integer :position, null: false
      t.json :configuration
      t.datetime :applied_at

      t.timestamps

      t.index [ :recipe_id, :position ], unique: true
    end
  end
end
