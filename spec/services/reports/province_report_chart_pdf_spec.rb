require "rails_helper"

# End-to-end through the real Python/matplotlib subprocess. Skipped (not failed)
# where the chart runtime isn't provisioned — see script/charts/README.md.
RSpec.describe Reports::ProvinceReportChartPdf do
  before { skip("chart runtime not provisioned") unless described_class.available? }

  let(:hcm) { create(:province, name: "Hồ Chí Minh") }

  it "renders the report as a PDF byte string" do
    create(:real_estate, crawl_province: hcm, type: "condo", bedrooms: 2, price: 4_000_000_000, area: 50.0)
    create(:real_estate, crawl_province: hcm, type: "land", bedrooms: nil, price: 9_000_000_000, area: 100.0)

    pdf = described_class.call(Reports::ProvinceReport.call(hcm))

    expect(pdf[0, 4]).to eq("%PDF")
    expect(pdf.bytesize).to be > 1_000
  end

  it "renders even when the province has no listings" do
    pdf = described_class.call(Reports::ProvinceReport.call(hcm))
    expect(pdf[0, 4]).to eq("%PDF")
  end

  it "raises GenerationError when the script exits non-zero" do
    allow(described_class).to receive(:python).and_return("false") # the /usr/bin/false no-op
    expect { described_class.call(Reports::ProvinceReport.call(hcm)) }
      .to raise_error(described_class::GenerationError)
  end
end
