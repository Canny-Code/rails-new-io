threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

rails_env = ENV.fetch("RAILS_ENV", "development")
environment rails_env

case rails_env
when "production"
  app_path = ENV.fetch("APP_PATH") { Dir.pwd }
  bind "unix://#{app_path}/tmp/puma.sock"
  port ENV.fetch("PORT", 3000)
  pidfile "#{app_path}/tmp/puma.pid"
  state_path "#{app_path}/tmp/puma.state"

  require "concurrent-ruby"
  workers_count = Integer(ENV.fetch("WEB_CONCURRENCY") { Concurrent.available_processor_count })
  workers workers_count if workers_count > 1

  preload_app!
when "development"
  # Specifies a very generous `worker_timeout` so that the worker
  # isn't killed by Puma when suspended by a debugger.
  port ENV.fetch("PORT", 3000)
  worker_timeout 3600
end

plugin :tmp_restart
plugin :litestream
plugin :solid_queue

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
