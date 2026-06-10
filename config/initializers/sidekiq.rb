require "sidekiq"
require "sidekiq/throttled"

redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
  # Per-supplier rate/concurrency limits live in each Fetch job (sidekiq-throttled),
  # enforced across all worker processes so parallel children don't hammer one host.
  config.server_middleware do |chain|
    chain.add Sidekiq::Throttled::Middleware if defined?(Sidekiq::Throttled::Middleware)
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
