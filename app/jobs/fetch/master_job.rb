module Fetch
  # Fans out one SupplierJob per (enabled supplier × scheduled province). Runs on a
  # q6h cron. The unique-job guard + per-supplier politeness live in SupplierJob's
  # sidekiq-throttled config, so the master can enqueue freely.
  class MasterJob
    include Sidekiq::Job

    sidekiq_options queue: "default", retry: 3

    def perform
      Province.scheduled.find_each do |province|
        SupplierJob::SUPPLIERS.each_key do |supplier|
          SupplierJob.perform_async(supplier, province.id)
        end
      end
    end
  end
end
