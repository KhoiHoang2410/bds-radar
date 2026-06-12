class BackfillRealEstateListingDetails < ActiveRecord::Migration[8.0]
  # RealEstate is 1:1 with RealEstateSource, which already carries these columns
  # (promoted in #21). Copy them across so existing normalized rows are filled
  # without waiting for the next Normalize::ProvinceJob sweep.
  def up
    execute(<<~SQL.squish)
      UPDATE real_estates re
      SET bedrooms = res.bedrooms,
          bathrooms = res.bathrooms,
          posted_at = res.posted_at,
          title = res.title
      FROM real_estate_sources res
      WHERE re.real_estate_source_id = res.id
    SQL
  end

  def down
    execute(<<~SQL.squish)
      UPDATE real_estates
      SET bedrooms = NULL, bathrooms = NULL, posted_at = NULL, title = NULL
    SQL
  end
end
