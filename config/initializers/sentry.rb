# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = "https://9a5d6b46b2aceb55085f3813b9862aff@o4508342968975360.ingest.de.sentry.io/4508342982934608"
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  # Set traces_sample_rate to 1.0 to capture 100%
  # of transactions for tracing.
  # We recommend adjusting this value in production.
  config.traces_sample_rate = 1.0
  # or
  config.traces_sampler = lambda do |context|
    true
  end
  # Set profiles_sample_rate to profile 100%
  # of sampled transactions.
  # We recommend adjusting this value in production.
  config.profiles_sample_rate = 0.5
end
