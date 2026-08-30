class AddSourceVersionToDatasets < ActiveRecord::Migration[8.0]
  def change
    add_column :datasets, :source_version, :string
    add_index :datasets, :source_version
  end
end
