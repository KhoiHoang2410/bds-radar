class BackfillNhatotListingDetails < ActiveRecord::Migration[8.0]
  # nhatot stores the verbatim ad in raw_data, so the new columns can be populated
  # retroactively without a re-crawl. mogi pre-discards source HTML, so its rows can
  # only be filled by a re-scrape (out of scope here).
  def up
    RealEstateSource.where(supplier: "nhatot").find_each do |source|
      raw = source.raw_data
      list_time = raw["list_time"]

      source.update_columns(
        bedrooms: raw["rooms"],
        bathrooms: raw["toilets"],
        posted_at: (Time.zone.at(list_time / 1000) if list_time),
        title: raw["subject"]
      )
    end
  end

  def down
    RealEstateSource.where(supplier: "nhatot")
                    .update_all(bedrooms: nil, bathrooms: nil, posted_at: nil, title: nil)
  end
end
