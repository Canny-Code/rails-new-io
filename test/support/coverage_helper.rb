module CoverageHelper
  def skip_coverage?
    ENV["SKIP_COVERAGE"] == "1"
  end
end
