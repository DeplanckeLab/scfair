require "json"

namespace :scfair do
  desc "Export per-dataset cell metadata as JSON, modelled on the CELLxGENE curation API /datasets format (OUTPUT=path, STATUS=completed|failed|processing|all; defaults: /data/scfair/cell_metadata.json, completed)"
  task export_cell_metadata_json: :environment do
    output = ENV.fetch("OUTPUT", "/data/scfair/cell_metadata.json")
    status = ENV.fetch("STATUS", "completed")

    # CELLxGENE field name => Dataset association
    term_fields = {
      "assay" => :technologies,
      "cell_type" => :cell_types,
      "development_stage" => :developmental_stages,
      "disease" => :diseases,
      "organism" => :organisms,
      "sex" => :sexes,
      "tissue" => :tissues
    }

    scope = Dataset.includes(
      :source, :study, :file_resources, :suspension_types,
      *term_fields.values.map { |assoc| { assoc => :ontology_term } }
    )
    scope = scope.where(status: status) unless status == "all"

    journals = Journal.pluck(:id, :name).to_h

    terms = lambda do |items|
      items.sort_by { |i| i.name.to_s.downcase }
           .map { |i| { "label" => i.name, "ontology_term_id" => i.ontology_term&.identifier } }
    end

    doi_label = lambda do |study|
      next nil if study.nil? || study.first_author.blank?

      label = "#{study.first_author} et al."
      label += " (#{study.year})" if study.year.present?
      journal = journals[study.journal_id]
      label += " #{journal}" if journal.present?
      label
    end

    count = 0
    File.open(output, "w") do |f|
      f.write("[")
      scope.find_each do |dataset|
        entry = {}
        entry["assay"] = terms.call(dataset.technologies)
        entry["assets"] = dataset.file_resources.sort_by(&:filetype).map do |r|
          { "filetype" => r.filetype.upcase, "title" => r.title.presence, "url" => r.url }
        end
        entry["cell_count"] = dataset.cell_count
        entry["cell_type"] = terms.call(dataset.cell_types)
        entry["collection_doi"] = dataset.doi.presence
        entry["collection_doi_label"] = doi_label.call(dataset.study)
        entry["collection_id"] = dataset.collection_id
        entry["dataset_id"] = dataset.id
        entry["development_stage"] = terms.call(dataset.developmental_stages)
        entry["disease"] = terms.call(dataset.diseases)
        entry["explorer_url"] = dataset.explorer_url
        entry["organism"] = terms.call(dataset.organisms)
        entry["processing_status"] = dataset.status.upcase
        entry["sex"] = terms.call(dataset.sexes)
        # scFAIR-specific: where the dataset was harvested from
        entry["source"] = { "name" => dataset.source&.name, "slug" => dataset.source&.slug }
        entry["source_reference_id"] = dataset.source_reference_id
        entry["source_url"] = dataset.source_url
        entry["source_version"] = dataset.source_version
        entry["suspension_type"] = dataset.suspension_types.map(&:name).sort
        entry["tissue"] = terms.call(dataset.tissues)

        f.write(",") if count.positive?
        f.write(JSON.generate(entry))
        count += 1
      end
      f.write("]")
    end

    puts "Exported #{count} datasets to #{output}"
  end
end
