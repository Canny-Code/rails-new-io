require "test_helper"

class DeleteIngredientJobTest < ActiveJob::TestCase
  def setup
    @user = users(:john)
    @ingredient = ingredients(:rails_authentication)
    @github_template_path = "templates/authentication"
    @local_template_path = "local/templates/authentication"
    @repo_name = "test-data-repo"

    DataRepositoryService.stubs(:name_for_environment).returns(@repo_name)
  end

  test "successfully deletes ingredient" do
    mock_service = mock
    DataRepositoryService.expects(:new)
                        .with(user: @user)
                        .returns(mock_service)

    mock_service.expects(:delete_ingredient)
                .with(
                  ingredient_name: @ingredient.name,
                  github_template_path: @github_template_path,
                  local_template_path: @local_template_path,
                  repo_name: @repo_name
                )
                .once

    assert_nothing_raised do
      DeleteIngredientJob.perform_now(
        user_id: @user.id,
        ingredient_name: @ingredient.name,
        github_template_path: @github_template_path,
        local_template_path: @local_template_path
      )
    end
  end

  test "raises error when user not found" do
    assert_raises ActiveRecord::RecordNotFound do
      DeleteIngredientJob.perform_now(
        user_id: -1,
        ingredient_name: @ingredient.name,
        github_template_path: @github_template_path,
        local_template_path: @local_template_path
      )
    end
  end

  test "raises error when DataRepositoryService fails" do
    mock_service = mock
    DataRepositoryService.expects(:new)
                        .with(user: @user)
                        .returns(mock_service)

    mock_service.expects(:delete_ingredient)
                .raises(StandardError.new("Service failure"))

    assert_raises StandardError do
      DeleteIngredientJob.perform_now(
        user_id: @user.id,
        ingredient_name: @ingredient.name,
        github_template_path: @github_template_path,
        local_template_path: @local_template_path
      )
    end
  end
end
