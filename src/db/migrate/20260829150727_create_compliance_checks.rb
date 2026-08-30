class CreateComplianceChecks < ActiveRecord::Migration[8.0]
  def change
    create_table :compliance_checks, id: :uuid, default: -> { "uuid_generate_v4()" } do |t|
      t.bigint :asap_id, null: false
      t.string :task_id
      t.string :filename
      t.string :source_url, null: false
      t.string :schema_id
      t.string :format
      t.boolean :passed
      t.string :status
      t.datetime :checked_at
      t.boolean :admin_run, null: false, default: false
      t.jsonb :result, null: false, default: {}
      t.references :file_resource, type: :uuid, foreign_key: true, null: true

      t.timestamps
    end

    add_index :compliance_checks, :asap_id, unique: true
    add_index :compliance_checks, :source_url
    add_index :compliance_checks, :passed
    add_index :compliance_checks, :checked_at
  end
end
