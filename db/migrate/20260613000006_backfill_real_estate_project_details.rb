class BackfillRealEstateProjectDetails < ActiveRecord::Migration[8.0]
  # RealEstate is 1:1 with RealEstateSource, which now carries the project columns
  # (backfilled + sibling-filled in 20260613000004). Copy them across so existing
  # normalized rows are filled without waiting for the next Normalize::ProvinceJob.
  def up
    execute(<<~SQL.squish)
      UPDATE real_estates re
      SET project_name = res.project_name,
          project_external_id = res.project_external_id
      FROM real_estate_sources res
      WHERE re.real_estate_source_id = res.id
    SQL
  end

  def down
    execute("UPDATE real_estates SET project_name = NULL, project_external_id = NULL")
  end
end
