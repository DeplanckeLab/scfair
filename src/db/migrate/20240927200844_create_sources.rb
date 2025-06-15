class CreateSources < ActiveRecord::Migration[8.0]
  def change
    create_table :sources, id: :uuid, default: -> { "uuid_generate_v4()" } do |t|
      t.string :slug, null: false, index: { unique: true }
      t.string :name, null: false, index: { unique: true }
      t.string :logo
      t.integer :completed_datasets_count, default: 0, null: false
      t.integer :failed_datasets_count, default: 0, null: false

      t.timestamps
    end
  end
end
