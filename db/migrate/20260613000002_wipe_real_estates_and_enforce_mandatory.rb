class WipeRealEstatesAndEnforceMandatory < ActiveRecord::Migration[8.0]
  # RealEstate is fully rebuilt from the retained RealEstateSource cache by normalize.
  # We wipe it so the new NOT NULL constraints can be added (existing nullable rows
  # would block them), and rename the matched-ward FK (ward_city_id -> ward_id) to
  # point at the renamed `wards` table.
  MANDATORY = %i[latitude longitude price area type province ward district_or_city].freeze

  def up
    execute "DELETE FROM real_estates"

    # rename_column auto-renames the index (index_real_estates_on_ward_city_id ->
    # index_real_estates_on_ward_id) on PostgreSQL.
    rename_column :real_estates, :ward_city_id, :ward_id
    add_foreign_key :real_estates, :wards, column: :ward_id

    MANDATORY.each { |col| change_column_null :real_estates, col, false }
  end

  def down
    MANDATORY.each { |col| change_column_null :real_estates, col, true }

    remove_foreign_key :real_estates, :wards, column: :ward_id
    rename_column :real_estates, :ward_id, :ward_city_id
  end
end
