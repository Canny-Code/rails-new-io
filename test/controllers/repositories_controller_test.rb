require "test_helper"

class RepositoriesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:john)
    sign_in @user
  end

  test "should get index" do
    get user_repositories_path(@user)
    assert_response :success
  end

  test "should get new" do
    get new_user_repository_path(@user)
    assert_response :success
  end

  test "check_name returns true for valid repository name" do
    validator = mock
    validator.expects(:valid?).returns(true)
    GithubRepositoryNameValidator.expects(:new)
      .with("test-repo", @user.github_username)
      .returns(validator)

    get check_repository_name_path, params: { name: "test-repo" }

    assert_response :success
    assert_equal({ "available" => true }, JSON.parse(response.body))
  end

  test "should create repository" do
    repository = Repository.new(
      name: "test-repo",
      github_url: "https://github.com/johndoe/test-repo",
      user: @user
    )

    service_mock = Minitest::Mock.new
    service_mock.expect :create_repository, repository do |name|
      repository.save!
      true
    end

    GithubRepositoryService.stub :new, service_mock do
      assert_difference("Repository.count") do
        post user_repositories_path(@user), params: { repository: { name: "test-repo" } }
      end
    end

    assert_redirected_to user_repositories_path(@user)
    assert_equal "Repository created successfully!", flash[:notice]
  end

  test "should handle repository creation error" do
    service_mock = Minitest::Mock.new
    service_mock.expect :create_repository, nil do |_name|
      raise GithubRepositoryService::Error, "API error"
    end

    GithubRepositoryService.stub :new, service_mock do
      post user_repositories_path(@user), params: { repository: { name: "test-repo" } }
    end

    assert_redirected_to new_user_repository_path(@user)
    assert_equal "API error", flash[:alert]
  end

  test "should redirect to root if not authenticated" do
    sign_out @user
    get user_repositories_path(@user)
    assert_redirected_to root_path
    assert_equal "Please sign in with GitHub first!", flash[:alert]
  end
end
