class AddRecipeToGeneratedApps < ActiveRecord::Migration[8.0]
  def up
    # Step 1: Add the column without the null constraint
    add_reference :generated_apps, :recipe, foreign_key: true

    # # Step 2: Create a default recipe if none exists
    # Recipe.skip_callback(:create, :after, :initial_git_commit)
    # default_recipe = Recipe.create!(
    #   name: "Default Recipe",
    #   cli_flags: "--skip-test",
    #   created_by: User.first # or some other way to get a valid user
    # )
    # Recipe.set_callback(:create, :after, :initial_git_commit)

    # # Step 3: Assign the default recipe to all existing generated apps
    # execute <<~SQL
    #   UPDATE generated_apps
    #   SET recipe_id = #{default_recipe.id}
    #   WHERE recipe_id IS NULL
    # SQL

    # Step 4: Add the null constraint
    change_column_null :generated_apps, :recipe_id, false
  end

  def down
    remove_reference :generated_apps, :recipe
  end
end
