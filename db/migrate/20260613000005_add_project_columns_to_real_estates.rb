class AddProjectColumnsToRealEstates < ActiveRecord::Migration[8.0]
  def change
    add_column :real_estates, :project_name, :string
    add_column :real_estates, :project_external_id, :string
    add_index :real_estates, :project_external_id
  end
end
