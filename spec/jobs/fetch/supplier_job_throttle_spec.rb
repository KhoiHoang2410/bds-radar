require "rails_helper"

# The unique-job guard (concurrency 1 per (supplier, province)) and the per-supplier
# rate limit are enforced by sidekiq-throttled at the fetch layer — assert they are
# registered for the worker.
RSpec.describe Fetch::SupplierJob, "throttling" do
  subject(:strategy) { Sidekiq::Throttled::Registry.get(described_class.name) }

  it "registers a sidekiq-throttled strategy" do
    expect(strategy).to be_present
  end

  it "has a concurrency strategy (the unique-job guard, keyed per supplier+province)" do
    expect(strategy.concurrency).to be_present
  end

  it "has a per-supplier rate threshold" do
    expect(strategy.threshold).to be_present
  end

  it "is a native Sidekiq worker (so the throttle applies)" do
    expect(described_class.ancestors).to include(Sidekiq::Job, Sidekiq::Throttled::Job)
  end
end
