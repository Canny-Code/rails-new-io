require "test_helper"

class GithubRepositoryNameValidatorTest < ActiveSupport::TestCase
  def setup
    @owner = "test-owner"
  end

  def test_valid_repository_name
    client = Minitest::Mock.new
    client.expect(:repository, nil) { raise Octokit::NotFound }

    Octokit::Client.stub(:new, client) do
      validator = GithubRepositoryNameValidator.new("valid-repo-name", @owner)
      assert validator.valid?
    end
  end

  def test_invalid_ending_with_hyphen
    validator = GithubRepositoryNameValidator.new("invalid-", @owner)
    refute validator.valid?
  end

  def test_invalid_starting_with_hyphen
    validator = GithubRepositoryNameValidator.new("-invalid", @owner)
    refute validator.valid?
  end

  def test_invalid_double_hyphen
    validator = GithubRepositoryNameValidator.new("invalid--name", @owner)
    refute validator.valid?
  end

  def test_invalid_empty_string
    validator = GithubRepositoryNameValidator.new("", @owner)
    refute validator.valid?
  end

  def test_invalid_special_characters
    validator = GithubRepositoryNameValidator.new("inv@lid", @owner)
    refute validator.valid?
  end

  def test_invalid_when_repository_exists
    client = Minitest::Mock.new
    client.expect(:repository, true, ["#{@owner}/existing-repo"])

    Octokit::Client.stub(:new, client) do
      validator = GithubRepositoryNameValidator.new("existing-repo", @owner)
      refute validator.valid?
    end

    assert_mock client
  end

  def test_invalid_with_nil_name
    client = Minitest::Mock.new
    client.expect(:repository, nil) { raise Octokit::NotFound }

    Octokit::Client.stub(:new, client) do
      validator = GithubRepositoryNameValidator.new(nil, @owner)
      refute validator.valid?
    end
  end
end
