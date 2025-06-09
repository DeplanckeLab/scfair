class CreateOntologyCoverage < ActiveRecord::Migration[8.0]
  def change
    create_table :ontology_coverage, id: :uuid, default: -> { "uuid_generate_v4()" } do |t|
      t.string :source
      t.string :category
      t.integer :records
      t.integer :relationships
      t.integer :ontology_coverage

      t.timestamps
    end
    
    add_index :ontology_coverage, :source
    add_index :ontology_coverage, :category
    add_index :ontology_coverage, [:source, :category], unique: true
  end
end
