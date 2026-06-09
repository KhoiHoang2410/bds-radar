require "faraday"
require "faraday/retry"

module Suppliers
  # Transport ONLY: HTTP client with retry/backoff, status handling, and a throttle
  # hook. Returns the RAW response body (no parsing — mogi is HTML, not JSON).
  # Parsing lives in each subclass.
  class Base
    class FetchError < StandardError; end

    USER_AGENT = "Mozilla/5.0 (compatible; BdsRadar/1.0)".freeze
    TIMEOUT = 20
    RETRY_STATUSES = [ 429, 500, 502, 503, 504 ].freeze
    # Must include Faraday::RetriableResponse — that is how faraday-retry signals a
    # retriable *status*. Passing `exceptions:` replaces the defaults, so list them all.
    RETRY_EXCEPTIONS = [
      Errno::ETIMEDOUT, Timeout::Error, Faraday::TimeoutError,
      Faraday::ConnectionFailed, Faraday::RetriableResponse
    ].freeze

    def get(url, headers: {})
      throttle
      response = connection.get(url) do |req|
        req.headers.update(default_headers.merge(headers))
      end
      unless response.success?
        raise FetchError, "#{self.class.name} GET #{url} -> HTTP #{response.status}"
      end

      response.body
    rescue Faraday::RetriableResponse => e
      status = e.response.is_a?(Hash) ? e.response[:status] : e.response&.status
      raise FetchError, "#{self.class.name} GET #{url} -> HTTP #{status} (retries exhausted)"
    rescue Faraday::Error => e
      raise FetchError, "#{self.class.name} GET #{url} -> #{e.class}: #{e.message}"
    end

    private

    # Per-request politeness pause. The cross-process per-supplier limit is enforced
    # by sidekiq-throttled at the job layer; this is a per-instance backstop.
    def throttle
      sleep(throttle_interval) if throttle_interval.positive?
    end

    def throttle_interval
      0
    end

    def default_headers
      { "User-Agent" => USER_AGENT, "Accept" => "*/*" }
    end

    def connection
      @connection ||= Faraday.new do |f|
        f.request :retry,
                  max: 3,
                  interval: 0.5,
                  backoff_factor: 2,
                  retry_statuses: RETRY_STATUSES,
                  exceptions: RETRY_EXCEPTIONS
        f.options.timeout = TIMEOUT
        f.adapter Faraday.default_adapter
      end
    end
  end
end
