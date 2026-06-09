require "rails_helper"

RSpec.describe Fetch::MasterJob do
  it "enqueues one SupplierJob per (enabled supplier × scheduled province), skipping disabled" do
    hcm = create(:province, :scheduled, name: "Hồ Chí Minh")
    hanoi = create(:province, :scheduled, name: "Hà Nội")
    create(:province, name: "Lai Châu") # disabled

    allow(Fetch::SupplierJob).to receive(:perform_async)

    described_class.new.perform

    Fetch::SupplierJob::SUPPLIERS.each_key do |supplier|
      expect(Fetch::SupplierJob).to have_received(:perform_async).with(supplier, hcm.id).once
      expect(Fetch::SupplierJob).to have_received(:perform_async).with(supplier, hanoi.id).once
    end
    expected = Fetch::SupplierJob::SUPPLIERS.size * 2 # two scheduled provinces
    expect(Fetch::SupplierJob).to have_received(:perform_async).exactly(expected).times
  end
end
