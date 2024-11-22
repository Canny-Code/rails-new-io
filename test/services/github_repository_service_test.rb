require "test_helper"
require "minitest/mock"
require "ostruct"

class GithubRepositoryServiceTest < ActiveSupport::TestCase
  def setup
    Repository.delete_all
    @user = users(:john)

    @user.define_singleton_method(:github_token) { "fake-token" }

    @service = GithubRepositoryService.new(@user)
    @client = Minitest::Mock.new
    @repository_name = "test-repo"
  end

  test "creates a repository successfully" do
    response = OpenStruct.new(html_url: "https://github.com/#{@user.github_username}/#{@repository_name}")

    Octokit::Client.stub :new, @client do
      @client.expect :repository?, false, [ "#{@user.github_username}/#{@repository_name}" ]
      @client.expect :create_repository, response, [ @repository_name, {
        private: false,
        auto_init: false,
        description: "Repository created via railsnew.io"
      } ]

      assert_difference -> { @user.repositories.count }, 1 do
        result = @service.create_repository(@repository_name)
        assert_equal response.html_url, result.html_url
      end
    end

    @client.verify
  end

  test "raises error when repository already exists" do
    mock_client = Object.new
    def mock_client.repository?(*)
      true
    end

    Octokit::Client.stub :new, mock_client do
      error = assert_raises(GithubRepositoryService::RepositoryExistsError) do
        @service.create_repository(@repository_name)
      end

      assert_equal "Repository 'test-repo' already exists", error.message
    end
  end

  test "handles rate limit exceeded" do
    mock_client = Object.new
    def mock_client.repository?(*)
      raise Octokit::TooManyRequests.new(response_headers: {})
    end
    def mock_client.rate_limit
      OpenStruct.new(resets_at: Time.now)
    end

    Octokit::Client.stub :new, mock_client do
      error = assert_raises(GithubRepositoryService::ApiError) do
        @service.create_repository(@repository_name)
      end

      assert_match /Rate limit exceeded/, error.message
    end
  end

  test "handles general GitHub API errors" do
    mock_client = Object.new
    def mock_client.repository?(*)
      raise Octokit::Error.new(response_headers: {})
    end

    Octokit::Client.stub :new, mock_client do
      error = assert_raises(GithubRepositoryService::ApiError) do
        @service.create_repository(@repository_name)
      end

      assert_match /GitHub API error/, error.message
    end
  end

  test "repository_exists? returns false when client raises StandardError" do
    client_mock = Minitest::Mock.new
    client_mock.expect :repository?, nil do
      raise StandardError, "Random error"
    end

    @service.stub :client, client_mock do
      assert_equal false, @service.send(:repository_exists?, "test-repo")
    end
  end
end
