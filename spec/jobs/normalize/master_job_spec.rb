require "rails_helper"

RSpec.describe Normalize::MasterJob do
  it "enqueues exactly one ProvinceJob per scheduled province (and skips disabled ones)" do
    hcm = create(:province, :scheduled, name: "Hồ Chí Minh")
    hanoi = create(:province, :scheduled, name: "Hà Nội")
    create(:province, name: "Lai Châu") # disabled

    allow(Normalize::ProvinceJob).to receive(:perform_later)

    described_class.new.perform

    expect(Normalize::ProvinceJob).to have_received(:perform_later).with(hcm.id).once
    expect(Normalize::ProvinceJob).to have_received(:perform_later).with(hanoi.id).once
    expect(Normalize::ProvinceJob).to have_received(:perform_later).exactly(2).times
  end
end
