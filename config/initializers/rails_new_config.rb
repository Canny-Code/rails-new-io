# Centralized configuration for rails new defaults
module RailsNewConfig
  mattr_accessor :ruby_version, :rails_version

  # These will be updated when new versions are released
  self.ruby_version = "3.4.1"
  self.rails_version = "8.0.1"

  class << self
    def ruby_version_for_new_apps
      ruby_version
    end

    def rails_version_for_new_apps
      rails_version
    end
  end
end
