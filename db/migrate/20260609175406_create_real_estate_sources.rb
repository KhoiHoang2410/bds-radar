class CreateRealEstateSources < ActiveRecord::Migration[8.0]
  def change
    create_table :real_estate_sources do |t|
      t.string :supplier, null: false
      t.string :external_id, null: false
      # Canonical crawl unit (sweep/scope key), stamped by the fetch job. NOT the raw
      # parsed province string below. Association is `crawl_province` to avoid clashing
      # with the `province` string attribute.
      t.references :province, null: false, foreign_key: true
      t.string :status, null: false, default: "active"
      t.jsonb :raw_data, null: false, default: {}

      # Pre-parsed fields. The admin-path strings are RAW supplier text (drift) — used for
      # display / WardCity matching, never as the sweep key.
      t.string :address
      t.string :province        # raw parsed province string (e.g. "Tp Hồ Chí Minh")
      t.string :district_or_city
      t.string :ward
      t.string :street
      t.decimal :area, precision: 12, scale: 2          # m²
      t.bigint :price                                   # VND
      t.string :type
      t.string :image_urls, array: true, null: false, default: []
      t.string :source_url
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :real_estate_sources, [:supplier, :external_id], unique: true
    add_index :real_estate_sources, [:supplier, :province_id]
    add_index :real_estate_sources, :status
  end
end
