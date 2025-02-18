#!/usr/bin/env ruby

# Read the file and process each line
result = File.readlines(ARGV[0]).map do |line|
  key, value = line.strip.split(/\s+/, 2)
  value = '""' if value.nil? || value.empty?
  "#{key}=#{value}"
end.join(' ')

puts result
