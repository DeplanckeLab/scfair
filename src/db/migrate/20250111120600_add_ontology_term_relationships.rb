class AddOntologyTermRelationships < ActiveRecord::Migration[7.0]
  def change
    create_table :ontology_term_relationships, id: :uuid do |t|
      t.uuid :parent_id, null: false
      t.uuid :child_id, null: false
      t.string :relationship_type, null: false # 'is_a' or 'part_of'
      t.timestamps
    end

    add_index :ontology_term_relationships, [:parent_id, :child_id], unique: true
    add_index :ontology_term_relationships, :child_id
    
    # Remove the string columns we no longer need
    remove_column :ontology_terms, :parents, :string
    remove_column :ontology_terms, :children, :string
  end
end 