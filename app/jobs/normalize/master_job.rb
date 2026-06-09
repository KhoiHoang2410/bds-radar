module Normalize
  # Fans out one ProvinceJob per scheduled province (across all suppliers). Runs on a
  # q4h cron, decoupled from fetch — idempotent, may process unchanged sources.
  class MasterJob < ApplicationJob
    queue_as :default

    def perform
      Province.scheduled.find_each { |province| ProvinceJob.perform_later(province.id) }
    end
  end
end
