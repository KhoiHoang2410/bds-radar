class CreateProvinces < ActiveRecord::Migration[8.0]
  def change
    create_table :provinces do |t|
      t.string :name, null: false
      t.string :alternatives, array: true, null: false, default: []
      t.boolean :schedule_fetch, null: false, default: false
      t.integer :fetch_page_depth, null: false, default: 5

      t.timestamps
    end

    add_index :provinces, :name, unique: true
    add_index :provinces, :schedule_fetch
  end
end
