#!/usr/bin/env ruby
puts File.readlines('./tmp/debug.txt').grep(/DEBUG:/).map{ it.gsub('web    | DEBUG:', '') }
