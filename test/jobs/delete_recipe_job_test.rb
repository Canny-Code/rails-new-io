require "test_helper"

class DeleteRecipeJobTest < ActiveJob::TestCase
  setup do
    @user = users(:john)
    @recipe_name = "test_recipe"
    @repo_name = DataRepositoryService.name_for_environment
  end

  test "successfully deletes recipe" do
    data_repository_service = mock
    DataRepositoryService.expects(:new).with(user: @user).returns(data_repository_service)
    data_repository_service.expects(:delete_recipe).with(
      recipe_name: @recipe_name,
      repo_name: @repo_name
    )

    DeleteRecipeJob.perform_now(user_id: @user.id, recipe_name: @recipe_name)
  end

  test "raises error when user not found" do
    assert_raises(ActiveRecord::RecordNotFound) do
      DeleteRecipeJob.perform_now(user_id: 999, recipe_name: @recipe_name)
    end
  end

  test "raises error when DataRepositoryService fails" do
    data_repository_service = mock
    DataRepositoryService.expects(:new).with(user: @user).returns(data_repository_service)
    data_repository_service.expects(:delete_recipe).raises(StandardError.new("Something went wrong"))

    assert_raises(StandardError) do
      DeleteRecipeJob.perform_now(user_id: @user.id, recipe_name: @recipe_name)
    end
  end
end
