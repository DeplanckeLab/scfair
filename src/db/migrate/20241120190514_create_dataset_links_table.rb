class CreateDatasetLinksTable < ActiveRecord::Migration[8.0]
  def change
    create_table :dataset_links, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.references :dataset, type: :uuid, null: false, foreign_key: true
      t.string :url, null: false
      t.string :name
      t.timestamps
    end
  end
end
