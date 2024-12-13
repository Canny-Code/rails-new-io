# Exit if we're in production
if Rails.env.production?
  puts "🚫 Don't run seeds in production!"
  exit
end

# Remove the database clearing part since we're starting with a fresh database
# The fixtures will be loaded by the rake task before this seed file runs

# Keep the rest of your seed file for additional data that's not in fixtures
