class AddListingDetailColumnsToRealEstates < ActiveRecord::Migration[8.0]
  def change
    add_column :real_estates, :bedrooms, :integer
    add_column :real_estates, :bathrooms, :integer
    add_column :real_estates, :posted_at, :datetime
    add_column :real_estates, :title, :string

    # bedrooms drives the condo/land price-per-bedroom report aggregation.
    add_index :real_estates, :bedrooms
  end
end
