require "test_helper"

class WriteRecipeJobTest < ActiveJob::TestCase
  def setup
    @user = users(:john)
    @recipe = recipes(:blog_recipe)
  end

  test "writes recipe to data repository" do
    data_repository = mock
    DataRepositoryService.expects(:new).with(user: @user).returns(data_repository)
    data_repository.expects(:write_recipe)
      .with(@recipe, repo_name: DataRepositoryService.name_for_environment)

    WriteRecipeJob.perform_now(recipe_id: @recipe.id, user_id: @user.id)
  end

  test "raises if recipe not found" do
    error = assert_raises(ActiveRecord::RecordNotFound) do
      WriteRecipeJob.perform_now(recipe_id: -1, user_id: @user.id)
    end
    assert_match(/Couldn't find Recipe with 'id'=-1/, error.message)
  end

  test "raises if user not found" do
    error = assert_raises(ActiveRecord::RecordNotFound) do
      WriteRecipeJob.perform_now(recipe_id: @recipe.id, user_id: -1)
    end
    assert_match(/Couldn't find User with 'id'=-1/, error.message)
  end

  test "logs and re-raises unexpected errors" do
    data_repository = mock
    DataRepositoryService.expects(:new).with(user: @user).returns(data_repository)
    error = StandardError.new("Something went wrong")
    data_repository.expects(:write_recipe).raises(error)

    Rails.logger.stubs(:error) # Allow any other error calls
    Rails.logger.expects(:error).with("Unexpected error writing recipe: Something went wrong").once

    error_raised = assert_raises(StandardError) do
      WriteRecipeJob.perform_now(recipe_id: @recipe.id, user_id: @user.id)
    end
    assert_equal error, error_raised
  end
end
