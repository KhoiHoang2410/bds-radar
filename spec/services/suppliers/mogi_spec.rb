require "rails_helper"

RSpec.describe Suppliers::Mogi do
  let(:supplier) { described_class.new }
  let(:detail_url) do
    "https://mogi.vn/huyen-hoc-mon/mua-dat-tho-cu/ban-dat-hoc-mon-so-do-rieng-lo-dat-dep-gia-8-25-ty-id22741413"
  end

  describe "#parse_detail (against the captured live detail page)" do
    subject(:raw) { supplier.parse_detail(detail_url, mogi_detail_html) }

    it "extracts external_id, price (VN parser), and area in m² (Diện tích đất)" do
      expect(raw["external_id"]).to eq("22741413")
      expect(raw["price"]).to eq(8_250_000_000)
      expect(raw["area"]).to eq(145.0)
    end

    it "splits the detail-page address into ward / district / city / street" do
      expect(raw["ward"]).to eq("Xã Tân Xuân")
      expect(raw["district"]).to eq("Huyện Hóc Môn")
      expect(raw["city"]).to eq("TPHCM")
      expect(raw["street"]).to include("Ấp Mới 1")
    end

    it "reads coordinates from the map iframe q= param" do
      expect(raw["latitude"]).to be_within(0.0001).of(10.873875)
      expect(raw["longitude"]).to be_within(0.0001).of(106.601085)
    end

    it "collects cloud.mogi.vn images and filters the dmca badge" do
      expect(raw["images"]).to be_present
      expect(raw["images"]).to all(include("cloud.mogi.vn/images"))
      expect(raw["images"]).to all(satisfy { |u| !u.include?("dmca") })
    end

    it "reads the title (h1) and post date (Ngày đăng, DD/MM/YYYY)" do
      expect(raw["title"]).to include("Hóc Môn")
      expect(raw["posted_at"]).to eq(Time.zone.local(2026, 6, 8))
    end

    it "leaves bedrooms/bathrooms nil when the page has no such info-attr rows (land)" do
      expect(raw["bedrooms"]).to be_nil
      expect(raw["bathrooms"]).to be_nil
    end
  end

  describe "#parse_detail bedroom/bathroom info-attr rows" do
    let(:html) do
      <<~HTML
        <html><body>
          <h1>Bán nhà 3 phòng ngủ</h1>
          <div class="info-attr clearfix"><span>Phòng ngủ</span><span>3</span></div>
          <div class="info-attr clearfix"><span>Phòng tắm</span><span>2 phòng</span></div>
        </body></html>
      HTML
    end

    it "extracts the leading integer from the matching rows" do
      raw = supplier.parse_detail("https://mogi.vn/q/mua-nha-id9", html)
      expect(raw["bedrooms"]).to eq(3)
      expect(raw["bathrooms"]).to eq(2)
    end
  end

  describe "#type_from_url (structured, AI only as fallback)" do
    {
      "https://mogi.vn/q/mua-can-ho-abc-id1" => "condo",
      "https://mogi.vn/q/mua-nha-rieng-abc-id1" => "house",
      "https://mogi.vn/q/mua-dat-tho-cu-abc-id1" => "land",
      "https://mogi.vn/q/cho-thue-van-phong-abc-id1" => "commercial"
    }.each do |url, type|
      it "maps #{url} → #{type}" do
        expect(supplier.parse_detail(url, mogi_detail_html)["type"]).to eq(type)
      end
    end
  end

  describe "#extract_detail_urls (against the captured live list page)" do
    it "returns unique mogi detail URLs (relative + absolute), all ending -id<N>" do
      urls = supplier.extract_detail_urls(mogi_list_html)
      expect(urls.size).to eq(16)
      expect(urls).to all(start_with("https://mogi.vn/"))
      expect(urls).to all(match(/-id\d+\z/))
    end
  end

  describe "#each_listing (list → detail flow)" do
    let(:province) { create(:province, name: "Hồ Chí Minh") }
    let(:url1) { "https://mogi.vn/q/mua-nha-rieng/a-id111" }
    let(:url2) { "https://mogi.vn/q/mua-can-ho/b-id222" }

    it "fetches the list, then each detail, yielding parsed raws" do
      stub_request(:get, "https://mogi.vn/ho-chi-minh/mua-nha-dat")
        .to_return(status: 200, body: mogi_list_with(url1, url2))
      stub_request(:get, url1).to_return(status: 200, body: mogi_detail_html)
      stub_request(:get, url2).to_return(status: 200, body: mogi_detail_html)

      raws = []
      count = supplier.each_listing(province, 0) { |raw| raws << raw }

      expect(count).to eq(2)
      expect(raws.map { |r| r["external_id"] }).to contain_exactly("111", "222")
      expect(raws.map { |r| r["type"] }).to contain_exactly("house", "condo")
    end
  end
end
