require "rails_helper"

RSpec.describe Suppliers::Base do
  let(:url) { "https://example.test/data" }

  it "returns the raw response body on success (no parsing)" do
    stub_request(:get, url).to_return(status: 200, body: "<html>raw</html>")
    expect(described_class.new.get(url)).to eq("<html>raw</html>")
  end

  it "retries on a 5xx then succeeds" do
    stub_request(:get, url)
      .to_return({ status: 503, body: "" }, { status: 200, body: "ok" })

    expect(described_class.new.get(url)).to eq("ok")
    expect(a_request(:get, url)).to have_been_made.twice
  end

  it "raises FetchError on a non-success status" do
    stub_request(:get, url).to_return(status: 404, body: "")
    expect { described_class.new.get(url) }.to raise_error(Suppliers::Base::FetchError, /404/)
  end
end
