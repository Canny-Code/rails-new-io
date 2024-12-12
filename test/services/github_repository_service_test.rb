require "test_helper"
require "minitest/mock"
require "ostruct"

class GithubRepositoryServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:john)
    # Define github_token method to bypass encryption
    @user.define_singleton_method(:github_token) { "fake-token" }

    @generated_app = generated_apps(:pending_app)
    @app_status = @generated_app.app_status
    @app_status.update!(
      status: "pending",
      status_history: [],
      started_at: nil,
      completed_at: nil,
      error_message: nil
    )

    @service = GithubRepositoryService.new(@generated_app)
    @repository_name = "test-repo"
  end

  test "creates a repository successfully" do
    response = OpenStruct.new(html_url: "https://github.com/#{@user.github_username}/#{@repository_name}")

    mock_client = Minitest::Mock.new
    mock_client.expect :repository?, false, [ "#{@user.github_username}/#{@repository_name}" ]
    mock_client.expect :create_repository, response, [ @repository_name, {
      private: false,
      auto_init: false,
      description: "Repository created via railsnew.io"
    } ]

    @service.stub :client, mock_client do
      assert_difference -> { @user.repositories.count }, 1 do
        assert_difference -> { AppGeneration::LogEntry.count }, 3 do
          result = @service.create_repository(@repository_name)
          assert_equal response.html_url, result.html_url
        end
      end

      # Verify log entries
      log_entries = @generated_app.log_entries.recent_first
      assert_equal "GitHub repo #{@repository_name} created successfully", log_entries.first.message
      assert_equal "Creating repository: #{@repository_name}", log_entries.second.message
    end

    mock_client.verify
  end

  test "raises error when repository already exists" do
    mock_client = Object.new
    def mock_client.repository?(*)
      true
    end

    @service.stub :client, mock_client do
      assert_difference -> { AppGeneration::LogEntry.count }, 1 do # One error log entry
        error = assert_raises(GithubRepositoryService::RepositoryExistsError) do
          @service.create_repository(@repository_name)
        end

        assert_equal "Repository 'test-repo' already exists", error.message
      end

      # Verify log entry
      log_entry = @generated_app.log_entries.last
      assert log_entry.error?
      assert_equal "Repository 'test-repo' already exists", log_entry.message
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

    @service.stub :client, mock_client do
      # We expect 5 log entries:
      # 1. Warning for first rate limit hit
      # 2. Warning for second rate limit hit
      # 3. Warning for third rate limit hit
      # 4. Warning for fourth rate limit hit
      # 5. Final error after max retries
      assert_difference -> { AppGeneration::LogEntry.count }, 5 do
        error = assert_raises(GithubRepositoryService::ApiError) do
          @service.create_repository(@repository_name)
        end

        assert_match /Rate limit exceeded/, error.message
      end

      # Verify log entries
      log_entries = @generated_app.log_entries.recent_first
      assert log_entries[0].error?, "Last entry should be error"
      assert_match /Rate limit exceeded and retry attempts exhausted/, log_entries[0].message

      # Check that we have 4 warning entries for the retries
      assert_equal 4, log_entries[1..].count { |entry| entry.warn? }
      log_entries[1..].each do |entry|
        assert_match /Rate limit exceeded, waiting for reset/, entry.message
      end
    end
  end

  test "handles general GitHub API errors" do
    mock_client = Object.new
    def mock_client.repository?(*)
      raise Octokit::Error.new(response_headers: {})
    end

    @service.stub :client, mock_client do
      # We expect 4 log entries:
      # 1. Error for first attempt
      # 2. Error for first retry
      # 3. Error for second retry
      # 4. Final error after max retries
      assert_difference -> { AppGeneration::LogEntry.count }, 4 do
        error = assert_raises(GithubRepositoryService::ApiError) do
          @service.create_repository(@repository_name)
        end

        assert_match /GitHub API error/, error.message
      end

      # Verify log entries
      log_entries = @generated_app.log_entries.recent_first
      assert_equal 4, log_entries.count { |entry| entry.error? }

      log_entries.each do |entry|
        assert entry.error?
        assert_match /GitHub API error/, entry.message
        assert entry.metadata.key?("retry_count") if entry != log_entries.last
      end
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

  test "transitions to creating_github_repo state before creating repository" do
    service = GithubRepositoryService.new(@generated_app)

    # Track if creating_github_repo! was called
    creating_github_repo_called = false
    @generated_app.define_singleton_method(:create_github_repo!) do
      creating_github_repo_called = true
    end

    # Stub external calls
    service.stub(:repository_exists?, false) do
      mock_client = Minitest::Mock.new
      mock_response = Struct.new(:html_url).new("https://github.com/user/repo")
      mock_client.expect(:create_repository, mock_response, [ "test-repo", Hash ])

      service.stub(:client, mock_client) do
        service.create_repository("test-repo")
        assert creating_github_repo_called, "creating_github_repo! should have been called"
      end
    end
  end
end
