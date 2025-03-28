namespace :ontology_terms do
  desc "Find and update missing ontology_term_id based on tax_id"
  task update_for_organisms: :environment do
    organisms_to_update = Organism.where(ontology_term_id: nil).where.not(tax_id: nil)

    puts "Found #{organisms_to_update.count} organisms with missing ontology_term_id"

    updated_count = 0
    not_found_count = 0

    organisms_to_update.find_each do |organism|
      ncbi_taxon_identifier = "NCBITaxon:#{organism.tax_id}"
      ontology_term = OntologyTerm.find_by(identifier: ncbi_taxon_identifier)

      if ontology_term
        organism.update(ontology_term_id: ontology_term.id)
        updated_count += 1
      else
        not_found_count += 1
        puts "No ontology term found for organism #{organism.id} with tax_id #{organism.tax_id}"
      end
    end

    puts "Summary:"
    puts "- Total organisms processed: #{organisms_to_update.count}"
    puts "- Successfully updated: #{updated_count}"
    puts "- No matching ontology term found: #{not_found_count}"
  end
end
