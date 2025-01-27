class AppDomain
  class << self
    def url
      host = Rails.application.config.action_mailer.default_url_options[:host] ||
             Rails.application.routes.default_url_options[:host] ||
             ENV["APP_HOST"]

      port = Rails.application.config.action_mailer.default_url_options[:port] ||
             Rails.application.routes.default_url_options[:port] ||
             ENV["APP_PORT"]

      protocol = Rails.application.config.force_ssl ? "https" : "http"

      if port
        "#{protocol}://#{host}:#{port}"
      else
        "#{protocol}://#{host}"
      end
    end
  end
end
