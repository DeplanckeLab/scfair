class AddStatusAndNotesToDatasets < ActiveRecord::Migration[8.0]
  def change
    add_column :datasets, :status, :string, default: "processing", null: false
    add_column :datasets, :notes, :jsonb, default: {}
    
    add_index :datasets, :status
  end
end
