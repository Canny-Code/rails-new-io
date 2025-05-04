require "fileutils"
require "rbconfig"

RAILS_GEN_ROOT = "/var/lib/rails-new-io/rails-env".freeze
RUBY_VERSION = "3.4.1".freeze
RAILS_VERSION = "8.0.2".freeze
BUNDLER_VERSION = "2.6.3".freeze

def ruby_platform
  @ruby_platform ||= begin
    platform_cmd = "#{RAILS_GEN_ROOT}/ruby/bin/ruby -e 'puts RUBY_PLATFORM'"
    platform = `#{platform_cmd}`.strip
    return platform unless platform.empty?

    # Fallback in case the command fails
    case RbConfig::CONFIG["host_os"]
    when /darwin/
      "arm64-darwin24"
    else
      "x86_64-linux"
    end
  end
end

def run_command(cmd, env = {})
  puts "Running: #{cmd}"
  # Base environment with everything we want to unset
  clean_env = {
    # Bundler
    "BUNDLE_GEMFILE" => nil,
    "BUNDLE_BIN" => nil,
    "BUNDLE_PATH" => nil,
    "BUNDLE_USER_HOME" => nil,
    "BUNDLE_APP_CONFIG" => nil,
    "BUNDLE_DISABLE_SHARED_GEMS" => nil,
    # Ruby
    "GEM_HOME" => nil,
    "GEM_PATH" => nil,
    "RUBYOPT" => nil,
    "RUBYLIB" => nil,
    "RUBY_ROOT" => nil,
    "RUBY_ENGINE" => nil,
    "RUBY_VERSION" => nil,
    "RUBY_PATCHLEVEL" => nil,
    # asdf
    "ASDF_DIR" => nil,
    "ASDF_DATA_DIR" => nil,
    "ASDF_CONFIG_FILE" => nil,
    "ASDF_DEFAULT_TOOL_VERSIONS_FILENAME" => nil,
    "ASDF_RUBY_VERSION" => nil,
    "ASDF_GEM_HOME" => nil,
    # RVM
    "rvm_bin_path" => nil,
    "rvm_path" => nil,
    "rvm_prefix" => nil,
    "rvm_ruby_string" => nil,
    "rvm_version" => nil,
    # rbenv
    "RBENV_VERSION" => nil,
    "RBENV_ROOT" => nil,
    # chruby
    "RUBY_AUTO_VERSION" => nil,
    # Minimal PATH with only what we need
    "PATH" => case RbConfig::CONFIG["host_os"]
              when /darwin/
      "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
              else
      "#{RAILS_GEN_ROOT}/ruby/bin:/usr/local/bin:/usr/bin:/bin"
              end
  }.merge(env)

  success = system(clean_env, cmd)
  unless success
    puts "Command failed with status: #{$?.exitstatus}"
    puts "STDERR: #{`#{cmd} 2>&1`}"
    raise "Command failed: #{cmd}"
  end
end

def install_system_dependencies
  return if ENV["RAILS_BUILD"] # Skip in Docker

  puts "Installing system dependencies..."
  case RbConfig::CONFIG["host_os"]
  when /darwin/
    run_command("brew update")
    run_command("brew install openssl@3 readline libyaml gmp jemalloc ruby-install")
  end
end

def setup_ruby
  return if ENV["RAILS_BUILD"] # Skip in Docker

  puts "Creating directory structure..."
  FileUtils.mkdir_p(RAILS_GEN_ROOT)
  FileUtils.mkdir_p("#{RAILS_GEN_ROOT}/gems")
  FileUtils.mkdir_p("#{RAILS_GEN_ROOT}/bundle")

  ruby_dir = "#{RAILS_GEN_ROOT}/ruby"
  unless Dir.exist?(ruby_dir) && File.executable?("#{ruby_dir}/bin/ruby")
    puts "Installing Ruby #{RUBY_VERSION}..."

    jemalloc_path = case RbConfig::CONFIG["host_os"]
    when /darwin/
      "/usr/local/opt/jemalloc"
    else
      "/usr"
    end

    env = {
      "optflags" => "-O3",
      "RUBY_INSTALL_OPTS" => "--disable-install-doc --disable-install-rdoc --disable-install-capi",
      "RUBY_CONFIGURE_OPTS" => "--disable-install-doc --disable-install-rdoc --disable-install-capi --enable-shared --enable-yjit --with-jemalloc --with-jemalloc-dir=#{jemalloc_path} --with-opt-dir=/usr/local/opt/openssl@3:/usr/local/opt/readline:/usr/local/opt/libyaml:/usr/local/opt/gmp",
      # Explicitly unset all bundler/gem related env vars
      "BUNDLE_GEMFILE" => nil,
      "BUNDLE_BIN" => nil,
      "BUNDLE_PATH" => nil,
      "GEM_HOME" => nil,
      "GEM_PATH" => nil,
      "BUNDLE_USER_HOME" => nil
    }

    puts "Using environment variables:"
    env.each { |k, v| puts "  #{k}=#{v}" }
    puts "\nStarting Ruby installation..."

    run_command("ruby-install --no-reinstall --cleanup --install-dir #{ruby_dir} ruby #{RUBY_VERSION}", env)
  end
end

task :setup do
  begin
    install_system_dependencies
    setup_ruby

    # Base environment for gem operations
    gem_env = {
      # Minimal PATH with only our Ruby and system essentials
      "PATH" => "#{RAILS_GEN_ROOT}/ruby/bin:/usr/local/bin:/usr/bin:/bin",
      # Ruby environment
      "GEM_HOME" => "#{RAILS_GEN_ROOT}/gems",
      "GEM_PATH" => "#{RAILS_GEN_ROOT}/gems",
      # Bundler environment
      "BUNDLE_USER_HOME" => "#{RAILS_GEN_ROOT}/bundle",
      "BUNDLE_GEMFILE" => nil,
      "BUNDLE_BIN" => nil,
      "BUNDLE_PATH" => nil,
      "BUNDLE_APP_CONFIG" => nil,
      # Prevent Ruby environment leakage
      "RUBYOPT" => nil,
      "RUBYLIB" => nil,
      "RUBY_ROOT" => "#{RAILS_GEN_ROOT}/ruby",
      "RUBY_VERSION" => RUBY_VERSION,
      # Prevent version manager interference
      "ASDF_DIR" => nil,
      "ASDF_DATA_DIR" => nil,
      "ASDF_RUBY_VERSION" => nil,
      "RBENV_VERSION" => nil,
      "RBENV_ROOT" => nil,
      "rvm_bin_path" => nil,
      "rvm_path" => nil,
      "RUBY_AUTO_VERSION" => nil
    }

    puts "Installing Bundler #{BUNDLER_VERSION}..."
    run_command("gem install bundler -v #{BUNDLER_VERSION}", gem_env)

    puts "Installing Rails #{RAILS_VERSION}..."
    run_command("gem install rails -v #{RAILS_VERSION}", gem_env)

    puts "\nIsolated Ruby environment set up successfully!"
    puts "Ruby: #{RUBY_VERSION}"
    puts "Rails: #{RAILS_VERSION}"
    puts "Bundler: #{BUNDLER_VERSION}"
    puts "Location: #{RAILS_GEN_ROOT}"
  rescue => e
    puts "\nError during setup: #{e.message}"
    puts e.backtrace
    exit 1
  end
end
