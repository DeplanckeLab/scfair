require "csv"

namespace :scfair do
  desc "Export per-dataset cell metadata to a TSV file (OUTPUT=path, STATUS=completed|failed|processing|all; defaults: /data/scfair/cell_metadata.tsv, completed)"
  task export_cell_metadata: :environment do
    output = ENV.fetch("OUTPUT", "/data/scfair/cell_metadata.tsv")
    status = ENV.fetch("STATUS", "completed")

    categories = Dataset::ASSOCIATION_METHODS.values

    scope = Dataset.includes(:source, *categories.map { |c| { c => :ontology_term } })
    scope = scope.where(status: status) unless status == "all"

    header = %w[dataset_id source source_reference_id collection_id status cell_count doi source_url explorer_url]
    categories.each { |c| header += [c.to_s, "#{c}_ontology_ids"] }

    count = 0
    CSV.open(output, "w", col_sep: "\t") do |tsv|
      tsv << header
      scope.find_each do |dataset|
        row = [
          dataset.id, dataset.source&.name, dataset.source_reference_id, dataset.collection_id,
          dataset.status, dataset.cell_count, dataset.doi, dataset.source_url, dataset.explorer_url
        ]
        categories.each do |c|
          items = dataset.public_send(c).sort_by { |i| i.name.to_s.downcase }
          row << items.map(&:name).join("; ")
          row << items.map { |i| i.ontology_term&.identifier || "" }.join("; ")
        end
        tsv << row
        count += 1
      end
    end

    puts "Exported #{count} datasets to #{output}"
  end
end
