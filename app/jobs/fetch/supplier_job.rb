module Fetch
  # Crawls one (supplier, province) unit end-to-end (ADR-0002):
  #   1. Fetch-then-store: gather ALL pages into memory. Any HTTP/parse error here
  #      raises BEFORE any DB write, so a transient outage mutates nothing — retry.
  #   2. One transaction: deactivate the whole (supplier, province_id) scope, then
  #      upsert every fetched listing active. Re-seen ⇒ active; vanished ⇒ inactive.
  #
  # A native Sidekiq worker (not ActiveJob) so sidekiq-throttled can govern it:
  #   - concurrency 1 per (supplier, province_id) = the unique-job guard (no two of the
  #     same unit run at once, across all worker processes);
  #   - a per-supplier rate threshold = politeness to each host (mogi tight; nhatot
  #     tolerant). Limits are procs of the job args.
  class SupplierJob
    include Sidekiq::Job
    include Sidekiq::Throttled::Job

    sidekiq_options queue: "default", retry: 5

    sidekiq_throttle(
      concurrency: {
        limit: 1,
        key_suffix: ->(supplier, province_id) { "#{supplier}:#{province_id}" }
      },
      threshold: {
        limit: ->(supplier, _province_id) { supplier == "mogi" ? 1 : 20 },
        period: 60,
        key_suffix: ->(supplier, _province_id) { supplier }
      }
    )

    SUPPLIERS = { "nhatot" => Suppliers::Nhatot, "mogi" => Suppliers::Mogi }.freeze

    def perform(supplier_key, province_id)
      supplier = SUPPLIERS.fetch(supplier_key).new
      province = Province.find(province_id)
      run_started_at = Time.current

      listings = collect_listings(supplier, province)

      RealEstateSource.transaction do
        RealEstateSource.where(supplier: supplier_key, province_id: province.id)
                        .update_all(status: "inactive", updated_at: run_started_at)
        listings.each { |listing| upsert(listing, province, run_started_at) }
      end
    end

    private

    def collect_listings(supplier, province)
      listings = []
      province.fetch_page_depth.times do |page|
        count = supplier.each_listing(province, page) { |raw| listings << supplier.normalize(raw) }
        break if count.to_i.zero?
      end
      listings
    end

    def upsert(listing, province, seen_at)
      record = RealEstateSource.find_or_initialize_by(supplier: listing.supplier, external_id: listing.external_id)
      record.assign_attributes(
        listing.to_attributes.merge(province_id: province.id, status: "active", last_seen_at: seen_at)
      )
      record.save!
    end
  end
end
