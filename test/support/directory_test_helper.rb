# frozen_string_literal: true

module DirectoryTestHelper
  def self.included(base)
    base.class_eval do
      setup :setup_test_directories
      teardown :cleanup_test_directories
    end
  end

  def setup_test_directories
    @original_pwd = Dir.pwd
    @test_directories = []
    @test_root = create_test_root
  end

  def cleanup_test_directories
    return unless defined?(@original_pwd) && defined?(@test_directories)

    # Clean up test directories from within the original directory
    # This ensures we're not trying to delete directories we're currently in
    if @original_pwd && File.directory?(@original_pwd)
      safely_change_directory(@original_pwd) do
        Array(@test_directories).each do |dir|
          begin
            cleanup_git_locks(dir) if dir && File.directory?(dir)
            FileUtils.rm_rf(dir) if dir && File.directory?(dir)
          rescue SystemCallError
          end
        end
      end
    end
  end

  def create_test_directory(name = nil)
    raise "Test root directory not set" unless defined?(@test_root)

    dir = File.join(@test_root, name || SecureRandom.hex(8))
    FileUtils.mkdir_p(dir)
    @test_directories ||= []
    @test_directories << dir
    dir
  end

  def within_test_directory(dir = nil)
    dir ||= create_test_directory
    dir = create_test_directory(dir) unless File.directory?(dir)

    # Ensure the directory is under our test root
    unless dir.start_with?(@test_root)
      raise "Directory #{dir} is outside test root #{@test_root}"
    end

    safely_change_directory(dir) do
      yield dir if block_given?
    end
    dir
  end

  def init_git_repo(dir)
    return unless dir && File.directory?(dir)

    # Ensure the directory is under our test root
    unless dir.start_with?(@test_root)
      raise "Directory #{dir} is outside test root #{@test_root}"
    end

    cleanup_git_locks(dir)
    git_service = LocalGitService.new(working_directory: dir, logger: Rails.logger)
    git_service.in_working_directory do
      Open3.capture2("git init --quiet")
      Open3.capture2("git config user.name 'Test User'")
      Open3.capture2("git config user.email 'test@example.com'")
      # Create an initial commit to avoid "empty repository" issues
      FileUtils.touch(".keep")
      Open3.capture2("git add .keep 2>/dev/null")
      Open3.capture2("git commit -m 'Initial commit' --quiet")
    end
  end

  private

  def safely_change_directory(dir)
    return unless dir && File.directory?(dir)

    original_dir = Dir.pwd
    begin
      Dir.chdir(dir)
      yield if block_given?
    ensure
      Dir.chdir(original_dir) if File.directory?(original_dir)
    end
  end

  def create_test_root
    dir = File.join(Rails.root, "tmp", "test", "test_root_#{SecureRandom.hex(4)}")
    FileUtils.mkdir_p(dir)
    @test_directories ||= []
    @test_directories << dir
    dir
  end

  def cleanup_git_locks(dir)
    return unless dir && File.directory?(dir)

    # Common git lock files
    lock_files = [
      ".git/index.lock",
      ".git/config.lock",
      ".git/HEAD.lock"
    ]

    # In test mode, just try to remove without any checks
    lock_files.each do |lock_file|
      lock_path = File.join(dir, lock_file)
      begin
        File.unlink(lock_path) rescue nil
      rescue SystemCallError
      end
    end
  end
end
