require "test_helper"

class WriteIngredientJobTest < ActiveJob::TestCase
  def setup
    @user = users(:john)
    @ingredient = ingredients(:rails_authentication)
  end

  test "writes recipe to data repository" do
    data_repository = mock
    DataRepositoryService.expects(:new).with(user: @user).returns(data_repository)
    data_repository.expects(:write_ingredient)
      .with(@ingredient, repo_name: DataRepositoryService.name_for_environment)

    WriteIngredientJob.perform_now(ingredient_id: @ingredient.id, user_id: @user.id)
  end

  test "raises if recipe not found" do
    error = assert_raises(ActiveRecord::RecordNotFound) do
      WriteIngredientJob.perform_now(ingredient_id: -1, user_id: @user.id)
    end
    assert_match(/Couldn't find Ingredient with 'id'=-1/, error.message)
  end

  test "raises if user not found" do
    error = assert_raises(ActiveRecord::RecordNotFound) do
      WriteIngredientJob.perform_now(ingredient_id: @ingredient.id, user_id: -1)
    end
    assert_match(/Couldn't find User with 'id'=-1/, error.message)
  end

  test "logs and re-raises unexpected errors" do
    data_repository = mock
    DataRepositoryService.expects(:new).with(user: @user).returns(data_repository)
    error = StandardError.new("Something went wrong")
    data_repository.expects(:write_ingredient).raises(error)

    Rails.logger.stubs(:error) # Allow any other error calls
    Rails.logger.expects(:error).with("Unexpected error writing ingredient: Something went wrong").once

    error_raised = assert_raises(StandardError) do
      WriteIngredientJob.perform_now(ingredient_id: @ingredient.id, user_id: @user.id)
    end
    assert_equal error, error_raised
  end
end
