class RemoveGeneratedAppFromRecipes < ActiveRecord::Migration[8.0]
  def change
    remove_reference :recipes, :generated_app
  end
end
