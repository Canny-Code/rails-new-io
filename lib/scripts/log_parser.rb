#!/usr/bin/env ruby

filename = ARGV[0] || "log.txt"

begin
  File.foreach(filename) do |line|
    puts line if line.include?("%%%%%")
  end
rescue Errno::ENOENT
  puts "Error: File '#{filename}' not found"
  exit 1
rescue => e
  puts "Error: #{e.message}"
  exit 1
end
