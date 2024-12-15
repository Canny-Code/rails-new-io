require "test_helper"

class GithubRepositoryNameValidatorTest < ActiveSupport::TestCase
  def setup
    @owner = "test-owner"
  end

  def test_available_repository_name
    client = Minitest::Mock.new
    client.expect(:repository?, false, [ "#{@owner}/valid-repo-name" ])

    Octokit::Client.stub(:new, client) do
      validator = GithubRepositoryNameValidator.new("valid-repo-name", @owner)
      assert_not validator.repo_exists?
    end
  end

  def test_invalid_ending_with_hyphen
    validator = GithubRepositoryNameValidator.new("invalid-", @owner)
    assert_not validator.repo_exists?
  end

  def test_invalid_starting_with_hyphen
    validator = GithubRepositoryNameValidator.new("-invalid", @owner)
    assert_not validator.repo_exists?
  end

  def test_invalid_double_hyphen
    validator = GithubRepositoryNameValidator.new("invalid--name", @owner)
    assert_not validator.repo_exists?
  end

  def test_invalid_empty_string
    validator = GithubRepositoryNameValidator.new("", @owner)
    assert_not validator.repo_exists?
  end

  def test_invalid_special_characters
    validator = GithubRepositoryNameValidator.new("inv@lid", @owner)
    assert_not validator.repo_exists?
  end

  def test_invalid_when_repository_exists
    client = Minitest::Mock.new
    client.expect(:repository?, true, [ "#{@owner}/existing-repo" ])

    Octokit::Client.stub(:new, client) do
      validator = GithubRepositoryNameValidator.new("existing-repo", @owner)
      assert validator.repo_exists?
    end

    assert_mock client
  end

  def test_invalid_with_nil_name
    validator = GithubRepositoryNameValidator.new(nil, @owner)
    assert_not validator.repo_exists?
  end

  def test_handles_github_api_errors
    error = Octokit::Error.new(
      method: :get,
      url: "https://api.github.com/repos/#{@owner}/test-repo",
      status: 401,
      response_headers: {},
      body: { message: "Bad credentials" }
    )

    # Set up logger mock
    mock_logger = mock("logger")
    mock_logger.expects(:error).with(
      "GitHub API error: GET https://api.github.com/repos/#{@owner}/test-repo: 401 - Bad credentials"
    )
    Rails.stubs(:logger).returns(mock_logger)

    # Set up client mock to raise error
    client = Minitest::Mock.new
    client.expect(:repository?, nil) { raise error }

    Octokit::Client.stub(:new, client) do
      validator = GithubRepositoryNameValidator.new("test-repo", @owner)

      error = assert_raises(Octokit::Error) do
        validator.repo_exists?
      end

      assert_equal "GET https://api.github.com/repos/#{@owner}/test-repo: 401 - Bad credentials", error.message
    end

    assert_mock client
  end
end
