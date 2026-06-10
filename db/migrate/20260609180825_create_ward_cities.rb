class CreateWardCities < ActiveRecord::Migration[8.0]
  def change
    create_table :ward_cities do |t|
      # Post-2025 2-tier canonical shape (ward, province) — no district.
      t.string :ward, null: false
      t.string :province, null: false
      t.string :ward_alternatives, array: true, null: false, default: []
      t.string :province_alternatives, array: true, null: false, default: []

      t.timestamps
    end

    add_index :ward_cities, [:ward, :province], unique: true
    add_index :ward_cities, :province
  end
end
