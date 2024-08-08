# frozen_string_literal: true

class ApplicationComponent < Phlex::HTML
  include Phlex::Rails::Helpers::Routes

  if Rails.env.local?
    def before_template
      comment { "=== Before #{self.class.name} ===" }
      super
    end

    def after_template
      super
      comment { "=== After #{self.class.name} ===" }
    end
  end
end
