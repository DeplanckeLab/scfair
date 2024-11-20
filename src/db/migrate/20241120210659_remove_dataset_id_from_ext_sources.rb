class RemoveDatasetIdFromExtSources < ActiveRecord::Migration[8.0]
  def change
    if column_exists?(:ext_sources, :dataset_id)
      remove_column :ext_sources, :dataset_id, :uuid
      remove_index :ext_sources, :dataset_id if index_exists?(:ext_sources, :dataset_id)
    end
  end
end
