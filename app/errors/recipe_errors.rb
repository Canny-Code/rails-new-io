module RecipeErrors
  class IncompatibleIngredientError < StandardError
    def message
      "This ingredient is not compatible with the current recipe configuration"
    end
  end

  class GitSyncError < StandardError; end
end
