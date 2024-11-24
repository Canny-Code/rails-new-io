require "test_helper"
require "fileutils"

class GithubCodePushServiceTest < ActiveSupport::TestCase
  def root_directory_for_tests
    Rails.root.join("tmp/test_github_push_#{name}").freeze
  end

  def setup
    Repository.delete_all
    User.delete_all

    @user = User.create!(
      name: "John Doe",
      email: "john@example.com",
      github_username: "johndoe",
      github_token: "test-github-token-123",
      provider: "github",
      uid: SecureRandom.uuid
    )

    @repository_name = "test-repo"
    @source_path = File.join(root_directory_for_tests, "source")

    # Ensure clean state
    FileUtils.rm_rf(root_directory_for_tests)
    FileUtils.mkdir_p(@source_path)

    # Create test files synchronously
    %w[app config lib].each do |dir|
      FileUtils.mkdir_p(File.join(@source_path, dir))
    end

    {
      "test.txt" => "test content",
      "app/test.rb" => "puts 'test'",
      "config/application.rb" => "module Test; end",
      "lib/tasks/test.rake" => "task :test => :environment do; end"
    }.each do |path, content|
      full_path = File.join(@source_path, path)
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
    end

    @service = GithubCodePushService.new(@user, @repository_name, @source_path)
  end

  test "successfully pushes code to repository" do
    git_mock = Object.new
    called_methods = []

    git_mock.define_singleton_method(:config) do |name, value|
      called_methods << [ :config, name, value ]
    end

    git_mock.define_singleton_method(:add) do |options|
      called_methods << [ :add, options ]
    end

    git_mock.define_singleton_method(:commit) do |msg|
      called_methods << [ :commit, msg ]
    end

    git_mock.define_singleton_method(:add_remote) do |name, url|
      called_methods << [ :add_remote, name, url ]
    end

    git_mock.define_singleton_method(:push) do |remote, branch|
      called_methods << [ :push, remote, branch ]
    end

    Git.stub :init, git_mock do
      @service.push
    end

    expected_calls = [
      [ :config, "user.name", @user.name ],
      [ :config, "user.email", @user.email ],
      [ :add, { all: true } ],
      [ :commit, "Initial commit" ],
      [ :add_remote, "origin", "https://#{@user.github_token}@github.com/#{@user.github_username}/#{@repository_name}.git" ],
      [ :push, "origin", "main" ]
    ]

    expected_calls.each do |expected_call|
      assert_includes called_methods, expected_call
    end
  end

  test "handles git errors gracefully" do
    # Create a new service with the existing directory
    service = GithubCodePushService.new(@user, @repository_name, @source_path)

    # Mock Git.init to raise a Git error
    git_error = Git::Error.new("Git command failed: fatal: not a git repository")

    Git.stub :init, ->(_) { raise git_error } do
      error = assert_raises(GithubCodePushService::GitError) do
        service.push
      end

      assert_equal "Git operation failed: Git command failed: fatal: not a git repository", error.message
    end
  end

  test "handles missing source directory" do
    FileUtils.rm_rf(@source_path)

    error = assert_raises(GithubCodePushService::FileSystemError) do
      @service.push
    end

    assert_match /Source directory does not exist/, error.message
  end

  test "cleans up temporary directory" do
    git_mock = Object.new
    def git_mock.config(*); end
    def git_mock.add(*); end
    def git_mock.commit(*); end
    def git_mock.add_remote(*); end
    def git_mock.push(*); end

    Git.stub :init, git_mock do
      @service.push
    end

    temp_dir = @service.instance_variable_get(:@temp_dir)
    assert_not Dir.exist?(temp_dir)
  end

  test "raises FileSystemError when source path doesn't exist" do
    @service = GithubCodePushService.new(@user, @repository_name, "/nonexistent/path")

    error = assert_raises(GithubCodePushService::FileSystemError) do
      @service.push
    end
    assert_match(/Source directory does not exist/, error.message)
  end

  test "raises FileSystemError when IO operation fails" do
    # Create a read-only directory to trigger IOError
    FileUtils.mkdir_p(@source_path)
    FileUtils.chmod(0444, @source_path)

    error = assert_raises(GithubCodePushService::FileSystemError) do
      @service.push
    end
    assert_match(/File system operation failed/, error.message)
  ensure
    # Reset permissions so teardown can clean up
    FileUtils.chmod(0755, @source_path) if Dir.exist?(@source_path)
  end

  test "raises FileSystemError when IO operation fails due to permissions" do
    FileUtils.mkdir_p(@source_path)
    FileUtils.chmod(0000, @source_path)  # No permissions at all

    error = assert_raises(GithubCodePushService::FileSystemError) do
      @service.push
    end
    assert_match(/File system operation failed/, error.message)
  ensure
    FileUtils.chmod(0755, @source_path) if Dir.exist?(@source_path)
  end

  def teardown
    @user.destroy
    FileUtils.rm_rf(root_directory_for_tests)
  end
end
