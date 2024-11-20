class AddDatasetLinksCountToDatasets < ActiveRecord::Migration[8.0]
  def change
    add_column :datasets, :dataset_links_count, :integer, default: 0

    reversible do |dir|
      dir.up do
        Dataset.find_each { |dataset| Dataset.reset_counters(dataset.id, :dataset_links) }
      end
    end
  end
end