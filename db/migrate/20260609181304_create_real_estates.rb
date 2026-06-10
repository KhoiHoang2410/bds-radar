class CreateRealEstates < ActiveRecord::Migration[8.0]
  def change
    create_table :real_estates do |t|
      # Canonical: coords are the location identity (ADR-0001); province_id is the
      # canonical crawl province (reliable filter key). ward_city_id is best-effort.
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.references :province, null: false, foreign_key: true
      t.references :ward_city, null: true, foreign_key: true

      # v1 is 1:1 with a source (no cross-source merge yet). This FK is the idempotent
      # upsert key; v2 merge replaces it with source_urls-driven dedup.
      t.references :real_estate_source, null: false, foreign_key: true, index: { unique: true }

      # Raw display admin path (drift; not the filter key).
      t.string :province
      t.string :district_or_city
      t.string :ward

      t.decimal :area, precision: 12, scale: 2
      t.bigint :price
      t.string :type
      t.string :image_urls, array: true, null: false, default: []
      t.string :source_urls, array: true, null: false, default: []
      t.string :status, null: false, default: "active"

      t.timestamps
    end

    add_index :real_estates, :status
    add_index :real_estates, :type
    add_index :real_estates, :price
    add_index :real_estates, :area
    add_index :real_estates, [:latitude, :longitude]
  end
end
