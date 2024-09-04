module CoverageHelper
  def skip_coverage?
    Rails.env.production? || ENV["SKIP_COVERAGE"] == "1"
  end
end
