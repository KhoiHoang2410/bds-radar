class AddListingDetailColumnsToRealEstateSources < ActiveRecord::Migration[8.0]
  def change
    add_column :real_estate_sources, :bedrooms, :integer
    add_column :real_estate_sources, :bathrooms, :integer
    add_column :real_estate_sources, :posted_at, :datetime
    add_column :real_estate_sources, :title, :string
  end
end
