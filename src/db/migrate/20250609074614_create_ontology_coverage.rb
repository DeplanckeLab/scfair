class CreateOntologyCoverage < ActiveRecord::Migration[8.0]
  def change
    create_table :ontology_coverage, id: :uuid, default: -> { "uuid_generate_v4()" } do |t|
      t.references :source, type: :uuid, null: false, foreign_key: true
      t.string :category
      t.integer :records_count, null: false, default: 0
      t.integer :relationships_count, null: false, default: 0
      t.integer :records_with_ontology_count, null: false, default: 0
      t.integer :records_missing_ontology_count, null: false, default: 0
      t.integer :parsing_issues_count, null: false, default: 0
      t.boolean :manually_curated, default: false, null: false

      t.timestamps
    end
    
    add_index :ontology_coverage, :source_id, if_not_exists: true
    add_index :ontology_coverage, :category, if_not_exists: true
    add_index :ontology_coverage, [:source_id, :category], unique: true, if_not_exists: true
  end
end
