module ViteTestHelper
  def self.included(base)
    if base <= ActionDispatch::IntegrationTest
      base.setup :ensure_vite_assets_built
    elsif base <= ActionDispatch::SystemTest
      base.class_eval do
        def before_setup
          ensure_vite_assets_built
          super
        end
      end
    end
  end

  private
    def ensure_vite_assets_built
      return if File.exist?(Rails.root.join("public/vite-test/.vite/manifest.json"))

      puts "Building Vite assets for test environment..."
      system("bin/vite build") or raise "Failed to build Vite assets"
    end
end
