class CreateOntologyTerm < ActiveRecord::Migration[7.0]
  def change
    enable_extension "uuid-ossp"

    create_table :ontology_terms, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.string :identifier, null: false
      t.string :name, null: true
      t.string :description, null: true
      t.string :parents, null: true
      t.string :children, null: true
      t.timestamps
    end

    add_index :ontology_terms, :identifier, unique: true
  end
end
