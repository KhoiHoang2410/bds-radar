namespace :gazetteer do
  desc "Refresh db/data/ward_cities.json from provinces.open-api.vn v2 (post-2025 wards)"
  task refresh: :environment do
    require "faraday"
    require "faraday/retry"
    require "json"

    # canonical Province name => provinces.open-api.vn v2 code (post-2025 2-tier).
    # Add a row here when a new province is enabled for crawling.
    open_api_codes = { "Hà Nội" => 1, "Hồ Chí Minh" => 79, "Khánh Hòa" => 56 }

    conn = Faraday.new do |f|
      f.request :retry, max: 3, interval: 0.5
      f.options.timeout = 30
      f.adapter Faraday.default_adapter
    end

    gazetteer = {}
    open_api_codes.each do |name, code|
      resp = conn.get("https://provinces.open-api.vn/api/v2/p/#{code}?depth=2")
      raise "fetch failed for #{name} (code #{code}): HTTP #{resp.status}" unless resp.success?

      wards = JSON.parse(resp.body).fetch("wards", []).map { |w| w["name"] }.uniq.sort
      gazetteer[name] = wards
      puts "  #{name}: #{wards.size} wards"
    end

    path = Rails.root.join("db/data/ward_cities.json")
    File.write(path, "#{JSON.pretty_generate(gazetteer)}\n")
    puts "Wrote #{path} (#{gazetteer.values.sum(&:size)} wards). Run `rails db:seed` to load."
  end
end
