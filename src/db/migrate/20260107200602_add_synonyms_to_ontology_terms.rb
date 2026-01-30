class AddSynonymsToOntologyTerms < ActiveRecord::Migration[8.0]
  def change
    add_column :ontology_terms, :synonyms, :text, array: true, default: []
  end
end
