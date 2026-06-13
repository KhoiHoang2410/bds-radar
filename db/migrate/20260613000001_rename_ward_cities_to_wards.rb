class RenameWardCitiesToWards < ActiveRecord::Migration[8.0]
  # Post-2025 the province is a hard FK (not a fuzzy string), so the table is just
  # `wards` keyed by province_id. province + province_alternatives are gone — province
  # resolution is now exact via the FK, so the matcher only fuzzes ward names.
  def up
    # Drop the FK first; real_estates.ward_city_id is renamed + re-pointed at `wards`
    # by the next migration (20260613000002).
    remove_foreign_key :real_estates, :ward_cities
    drop_table :ward_cities

    create_table :wards do |t|
      t.string :ward, null: false
      t.references :province, null: false, foreign_key: true
      t.string :ward_alternatives, array: true, null: false, default: []

      t.timestamps
    end

    add_index :wards, [ :ward, :province_id ], unique: true
  end

  def down
    drop_table :wards

    create_table :ward_cities do |t|
      t.string :ward, null: false
      t.string :province, null: false
      t.string :ward_alternatives, array: true, null: false, default: []
      t.string :province_alternatives, array: true, null: false, default: []

      t.timestamps
    end
    add_index :ward_cities, [ :ward, :province ], unique: true
    add_index :ward_cities, :province

    add_foreign_key :real_estates, :ward_cities, column: :ward_city_id
  end
end
