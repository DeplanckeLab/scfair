class CreateParsingIssues < ActiveRecord::Migration[8.0]
  def change
    create_table :parsing_issues, id: :uuid, default: -> { "uuid_generate_v4()" } do |t|
      t.references :dataset, type: :uuid,null: false
      t.string :resource
      t.string :value
      t.string :message
      t.integer :status, default: 0, null: false

      t.timestamps
    end
  end
end
