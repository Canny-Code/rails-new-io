class AddGeneratedWithRecipeVersionColumnToGeneratedApps < ActiveRecord::Migration[8.0]
  def change
    add_column :generated_apps, :generated_with_recipe_version, :string, null: false, default: "unknown"
  end
end
