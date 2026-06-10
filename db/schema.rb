# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_06_09_180825) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "provinces", force: :cascade do |t|
    t.string "name", null: false
    t.string "alternatives", default: [], null: false, array: true
    t.boolean "schedule_fetch", default: false, null: false
    t.integer "fetch_page_depth", default: 5, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_provinces_on_name", unique: true
    t.index ["schedule_fetch"], name: "index_provinces_on_schedule_fetch"
  end

  create_table "real_estate_sources", force: :cascade do |t|
    t.string "supplier", null: false
    t.string "external_id", null: false
    t.bigint "province_id", null: false
    t.string "status", default: "active", null: false
    t.jsonb "raw_data", default: {}, null: false
    t.string "address"
    t.string "province"
    t.string "district_or_city"
    t.string "ward"
    t.string "street"
    t.decimal "area", precision: 12, scale: 2
    t.bigint "price"
    t.string "type"
    t.string "image_urls", default: [], null: false, array: true
    t.string "source_url"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.datetime "last_seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["province_id"], name: "index_real_estate_sources_on_province_id"
    t.index ["status"], name: "index_real_estate_sources_on_status"
    t.index ["supplier", "external_id"], name: "index_real_estate_sources_on_supplier_and_external_id", unique: true
    t.index ["supplier", "province_id"], name: "index_real_estate_sources_on_supplier_and_province_id"
  end

  create_table "ward_cities", force: :cascade do |t|
    t.string "ward", null: false
    t.string "province", null: false
    t.string "ward_alternatives", default: [], null: false, array: true
    t.string "province_alternatives", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["province"], name: "index_ward_cities_on_province"
    t.index ["ward", "province"], name: "index_ward_cities_on_ward_and_province", unique: true
  end

  add_foreign_key "real_estate_sources", "provinces"
end
