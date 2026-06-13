class AddProjectColumnsToRealEstateSources < ActiveRecord::Migration[8.0]
  # Condo project/building name + a stable project id. nhatot exposes both
  # (pty_project_name / project_oid); nullable because coverage is partial and other
  # suppliers/types don't carry them.
  def change
    add_column :real_estate_sources, :project_name, :string
    add_column :real_estate_sources, :project_external_id, :string
    add_index :real_estate_sources, :project_external_id
  end
end
