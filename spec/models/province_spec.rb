require "rails_helper"

RSpec.describe Province, type: :model do
  it "has a valid factory" do
    expect(build(:province)).to be_valid
  end

  it "requires a name" do
    expect(build(:province, name: nil)).not_to be_valid
  end

  it "requires a unique name" do
    create(:province, name: "Khánh Hòa")
    expect(build(:province, name: "Khánh Hòa")).not_to be_valid
  end

  it "rejects a non-positive fetch_page_depth" do
    expect(build(:province, fetch_page_depth: 0)).not_to be_valid
  end

  describe ".scheduled" do
    it "returns only provinces with schedule_fetch true" do
      on = create(:province, :scheduled)
      create(:province) # off

      expect(Province.scheduled).to contain_exactly(on)
    end
  end
end
