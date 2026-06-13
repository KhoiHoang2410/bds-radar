class BackfillNhatotProjectDetails < ActiveRecord::Migration[8.0]
  # nhatot keeps the verbatim ad in raw_data, so project columns backfill without a
  # re-crawl. Two passes:
  #   1. Lift pty_project_name / project_oid off raw_data.
  #   2. Sibling-fill: a condo often has a project_oid but a blank pty_project_name;
  #      borrow the name from another listing in the same project that does have one
  #      (most recently updated wins).
  # mogi pre-discards source HTML and carries no project field, so it's untouched.
  def up
    RealEstateSource.where(supplier: "nhatot").find_each do |source|
      raw = source.raw_data
      source.update_columns(
        project_name: raw["pty_project_name"].presence,
        project_external_id: raw["project_oid"].presence&.to_s
      )
    end

    execute(<<~SQL.squish)
      UPDATE real_estate_sources s
      SET project_name = named.project_name
      FROM (
        SELECT DISTINCT ON (project_external_id) project_external_id, project_name
        FROM real_estate_sources
        WHERE project_external_id IS NOT NULL AND project_name IS NOT NULL
        ORDER BY project_external_id, updated_at DESC
      ) named
      WHERE s.project_external_id = named.project_external_id
        AND s.project_name IS NULL
    SQL
  end

  def down
    RealEstateSource.where(supplier: "nhatot")
                    .update_all(project_name: nil, project_external_id: nil)
  end
end
