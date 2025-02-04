require "test_helper"

class GithubControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:jane)
    @user.stubs(:github_username).returns("jane_smith")
    sign_in(@user)
  end

  test "returns success when repository does not exist" do
    validator = mock("validator")
    validator.expects(:repo_can_be_created?).returns(true)
    GithubRepositoryNameValidator.expects(:new)
                                .with("test-repo", "jane_smith")
                                .returns(validator)

    get check_github_name_path, params: { name: "test-repo" }

    assert_response :success
    assert_equal({ "available" => true }, response.parsed_body)
  end

  test "returns failure when repository exists" do
    validator = mock("validator")
    validator.expects(:repo_can_be_created?).returns(false)
    GithubRepositoryNameValidator.expects(:new)
                                .with("existing-repo", "jane_smith")
                                .returns(validator)

    get check_github_name_path, params: { name: "existing-repo" }

    assert_response :success
    assert_equal({ "available" => false }, response.parsed_body)
  end

  test "handles unauthorized GitHub access" do
    validator = mock("validator")
    validator.expects(:repo_can_be_created?).raises(Octokit::Unauthorized)
    GithubRepositoryNameValidator.expects(:new)
                                .with("test-repo", "jane_smith")
                                .returns(validator)

    get check_github_name_path, params: { name: "test-repo" }

    assert_response :unauthorized
    assert_equal({ "error" => "GitHub authentication failed" }, response.parsed_body)
  end

  test "handles forbidden GitHub access" do
    validator = mock("validator")
    validator.expects(:repo_can_be_created?).raises(Octokit::Forbidden)
    GithubRepositoryNameValidator.expects(:new)
                                .with("test-repo", "jane_smith")
                                .returns(validator)

    get check_github_name_path, params: { name: "test-repo" }

    assert_response :unauthorized
    assert_equal({ "error" => "GitHub authentication failed" }, response.parsed_body)
  end

  test "handles other GitHub errors" do
    validator = mock("validator")
    validator.expects(:repo_can_be_created?).raises(Octokit::Error)
    GithubRepositoryNameValidator.expects(:new)
                                .with("test-repo", "jane_smith")
                                .returns(validator)

    get check_github_name_path, params: { name: "test-repo" }

    assert_response :unprocessable_entity
    assert_equal({ "error" => "Could not validate repository name" }, response.parsed_body)
  end

  test "requires authentication" do
    sign_out(@user)

    get check_github_name_path, params: { name: "test-repo" }

    assert_response :redirect
    assert_redirected_to root_path
    assert_equal "Please sign in first.", flash[:alert]
  end

  test "logs errors when GitHub authentication fails" do
    validator = mock("validator")
    error = Octokit::Unauthorized.new
    validator.expects(:repo_can_be_created?).raises(error)
    GithubRepositoryNameValidator.expects(:new)
                                .with("test-repo", "jane_smith")
                                .returns(validator)

    Rails.logger.expects(:error).with("GitHub authentication error: #{error.message}")

    get check_github_name_path, params: { name: "test-repo" }
  end

  test "logs errors for other GitHub validation failures" do
    validator = mock("validator")
    error = Octokit::Error.new
    validator.expects(:repo_can_be_created?).raises(error)
    GithubRepositoryNameValidator.expects(:new)
                                .with("test-repo", "jane_smith")
                                .returns(validator)

    Rails.logger.expects(:error).with("GitHub validation error: #{error.message}")

    get check_github_name_path, params: { name: "test-repo" }
  end
end
