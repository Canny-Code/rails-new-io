# Recipe system v1

## Common scenarios

Instead of explaining the components to boot, let's see a few common scenarios which demonstrate the way of using the recipe system:

1. **Creating a new Recipe**:

```ruby
# User creates a new recipe with initial CLI flags
recipe = Recipe.create!(
  name: "API Only App",
  cli_flags: "--api --skip-test",
  generated_app: generated_app
)

# This triggers GitBackedModel which:
# - Writes recipe data to rails-new-io-data/recipes/{id}/manifest.json
# - Creates initial commit in git
```

2. **Adding an Ingredient to a Recipe**:


```ruby
# User adds devise to their recipe
recipe.add_ingredient!(devise_ingredient, configuration: { api_only: true })
```

# This:
# 1. Checks compatibility via ingredient_compatible?()
#    - Verifies against conflicts_with
#    - Checks if required ingredients are present
# 2. Creates RecipeIngredient with next position
# 3. Creates a Commit recording this change
# 4. Updates git repository with new state

3. **Generating an App from a Recipe**:

```ruby
# When GeneratedApp executes its recipe:
recipe.recipe_ingredients.order(:position).each do |ri|
  # 1. Gets configured template content
  content = ri.ingredient.configuration_for(ri.configuration)

  # 2. Records the change
  app_change = app_changes.create!(
    ingredient: ri.ingredient,
    configuration: ri.configuration
  )

  # 3. Applies the change
  app_change.apply!

  # 4. Updates git repository
end
```

4. **Adding an Ingredient directly to an App**:

```ruby
# User adds Sidekiq to an existing app
app_change = app.app_changes.create!(
  ingredient: sidekiq_ingredient,
  configuration: { redis_url: "redis://localhost:6379/1" }
)
app_change.apply!

# This:
# 1. Records the change in app_changes
# 2. Applies the template with configuration
# 3. Updates git in generated_apps/{id}/history.json
```


## Key Components and Their Roles:

* **Ingredient**
  * Core template container
  * Handles compatibility rules
  * Manages configuration variants
  * Stores the actual Rails template code

* **Recipe**
  * Orders ingredients
  * Manages CLI flags
  * Tracks version history via commits
  * Ensures ingredient compatibility

* **RecipeIngredient**
  * Join model with position
  * Stores specific configuration
  * Handles template application

* **AppChange**
  * Records all changes to an app
  * Tracks success/failure
  * Stores specific configurations
  * Handles template application

* **Commit**
  * Git-like versioning
  * Stores full state snapshots
  * Enables reverting to previous states

* **GitBackedModel**
  * Syncs all changes to git
  * Manages GitHub repository
  * Handles concurrent modifications
