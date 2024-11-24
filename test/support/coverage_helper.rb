module CoverageHelper
  def skip_coverage?
    ENV["RAILS_ENV"] == "production" || ENV["SKIP_COVERAGE"] == "1"
  end
end
