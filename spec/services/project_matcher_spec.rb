require "rails_helper"

RSpec.describe ProjectMatcher do
  describe ".match (with an injected dictionary)" do
    let(:dictionary) { [ "The EverRich Infinity", "Akari City", "Saigon Pearl", "8X Rainbow" ] }

    def match(title)
      described_class.match(title, dictionary: dictionary)
    end

    it "finds a known project named in a mogi-style title" do
      expect(match("Bán căn hộ cao cấp The EverRich Infinity Quận 5 86m2 2PN")).to eq("The EverRich Infinity")
    end

    it "recognizes the project despite diacritics/case noise around it" do
      expect(match("ban can ho akari city gia tot")).to eq("Akari City")
    end

    it "returns nil when no known project appears in the title" do
      expect(match("Bán nhà mặt phố Quận 1 sổ hồng riêng")).to be_nil
    end

    it "tolerates a small typo within the error bound" do
      expect(match("can ho saigon pearl view dep")).to eq("Saigon Pearl")
    end

    it "prefers the longest (most specific) name on a tie" do
      result = described_class.match("ban can ho saigon pearl riverside",
                                     dictionary: [ "Saigon Pearl", "Saigon Pearl Riverside" ])
      expect(result).to eq("Saigon Pearl Riverside")
    end
  end

  describe ".dictionary" do
    it "is the distinct set of non-trivial nhatot project names" do
      create(:real_estate_source, supplier: "nhatot", project_name: "Akari City")
      create(:real_estate_source, supplier: "nhatot", project_name: "Akari City") # dup
      create(:real_estate_source, supplier: "nhatot", project_name: "Sun")          # too short, dropped
      create(:real_estate_source, supplier: "mogi", project_name: "Vinhomes")        # not nhatot
      create(:real_estate_source, supplier: "nhatot", project_name: nil)

      expect(described_class.dictionary).to contain_exactly("Akari City")
    end
  end
end
