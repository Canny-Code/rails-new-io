#!/usr/bin/env ruby

def transform_path(input_path)
  # Validate input
  unless input_path && input_path.start_with?('app/') && input_path.end_with?('.rb')
    puts "Error: Input must be a relative path starting with 'app/' and ending with '.rb'"
    exit 1
  end

  # Transform the path
  test_path = input_path
    .gsub(/^app\//, 'test/')
    .gsub(/\.rb$/, '_test.rb')

  # Execute the command and replace current process
  command = "bin/rails test #{test_path}"
  puts "Executing: #{command}"
  exec command
end

# Get the input path from command line argument
if ARGV.empty?
  puts "Usage: #{$0} app/path/to/file.rb"
  exit 1
end

transform_path(ARGV[0])
