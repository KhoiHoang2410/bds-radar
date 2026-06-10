source "https://rubygems.org"

gem "rails", "~> 8.0.5"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"

gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false

# Background jobs
# connection_pool 3.x uses anonymous-kwarg forwarding that Ruby 3.3.0 rejects; 2.4 is
# compatible across our Ruby line and satisfies Sidekiq 7.
gem "connection_pool", "~> 2.4"
gem "sidekiq", "~> 7.3"
gem "sidekiq-cron", "~> 2.0"
gem "sidekiq-throttled", "~> 1.5"
gem "redis", "~> 5.3"

# API serialization + param validation
# roar = decorator-based representers (roar-rails is unmaintained / Rails-8 incompatible,
# so we use roar core directly: Representer.new(model).to_json / .from_json in controllers).
gem "roar", "~> 1.2"
gem "multi_json"
gem "dry-validation", "~> 1.10"

# Index filtering + pagination (don't hand-roll): ransack q[...] predicates, pagy paging.
gem "ransack", "~> 4.2"
gem "pagy", "~> 9.3"

# HTTP transport + HTML parsing (suppliers)
gem "faraday", "~> 2.12"
gem "faraday-retry", "~> 2.2"
gem "nokogiri", "~> 1.16"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "rubocop-rails-omakase", require: false

  gem "rspec-rails", "~> 7.1"
  gem "factory_bot_rails", "~> 6.4"
  gem "webmock", "~> 3.24"
  gem "vcr", "~> 6.3"
  gem "parallel_tests", "~> 4.7"
end
