class CreateOntologyTerm < ActiveRecord::Migration[7.0]
  def change
    enable_extension "citext" unless extension_enabled?("citext")
    enable_extension "uuid-ossp"

    create_table :ontology_terms, id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
      t.citext :identifier, null: false
      t.citext :name, null: true
      t.string :description, null: true
      t.string :parents, null: true
      t.string :children, null: true
      t.timestamps

      t.index :identifier, unique: true
      t.index :name
    end
  end
end
