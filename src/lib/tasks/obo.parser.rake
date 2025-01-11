require "rake"

def print_progress(current, total, title = "Progress")
  width = 50
  progress = current.to_f / total
  filled = (progress * width).to_i
  empty = width - filled
  percent = (progress * 100).to_i
  print "\r#{title}: [#{'=' * filled}#{' ' * empty}] #{percent}% (#{current}/#{total})"
end

namespace :obo do
  desc "Parse .obo file and update Ontology table"
  task :parse, [:file_path] => :environment do |t, args|
    file_path = args[:file_path]

    if file_path.nil?
      puts "Usage: rake obo:parse[file_path]"
      exit
    end

    # Count total lines
    puts "\nCounting lines..."
    total_lines = File.foreach(file_path).count
    puts "Found #{total_lines} lines"

    terms_to_create = {}
    relationships_to_create = []
    current_term = {}
    current_relationships = []
    line_count = 0

    # First pass: collect all terms and relationships
    puts "\nParsing file..."
    File.foreach(file_path) do |line|
      line_count += 1
      print_progress(line_count, total_lines, "Parsing") if line_count % 100 == 0
      
      line.chomp!
      
      case line
      when "[Term]"
        if current_term[:identifier].present?
          terms_to_create[current_term[:identifier]] = {
            identifier: current_term[:identifier],
            name: current_term[:name],
            description: current_term[:description]
          }
          relationships_to_create.concat(current_relationships)
        end
        current_term = {}
        current_relationships = []
      when /^id: (.+)/
        current_term[:identifier] = $1.strip if $1.match?(/^[A-Za-z]+:\d+$/)
      when /^name: (.+)/
        current_term[:name] = $1.strip
      when /^def: "([^"]+)".*$/
        current_term[:description] = $1.strip
      when /^is_a: ([A-Za-z]+:\d+)/
        current_relationships << { 
          child_identifier: current_term[:identifier],
          parent_identifier: $1.strip,
          relationship_type: 'is_a'
        }
      when /^relationship: part_of ([A-Za-z]+:\d+)/
        current_relationships << {
          child_identifier: current_term[:identifier],
          parent_identifier: $1.strip,
          relationship_type: 'part_of'
        }
      end
    end
    print_progress(total_lines, total_lines, "Parsing")
    puts "\n"

    # Add the last term if present
    if current_term[:identifier].present?
      terms_to_create[current_term[:identifier]] = {
        identifier: current_term[:identifier],
        name: current_term[:name],
        description: current_term[:description]
      }
      relationships_to_create.concat(current_relationships)
    end

    # Bulk create/update terms
    puts "\nCreating/updating #{terms_to_create.size} terms..."
    terms_processed = 0
    ActiveRecord::Base.transaction do
      terms_to_create.each_slice(1000) do |terms_batch|
        terms_batch.each do |identifier, attributes|
          OntologyTerm.find_or_initialize_by(identifier: identifier).update!(attributes)
          terms_processed += 1
          print_progress(terms_processed, terms_to_create.size, "Terms") if terms_processed % 10 == 0
        end
      end
    end
    print_progress(terms_to_create.size, terms_to_create.size, "Terms")
    puts "\n"

    # Create a mapping of identifiers to IDs for relationship creation
    puts "\nBuilding identifier mapping..."
    identifier_to_id = OntologyTerm.where(identifier: terms_to_create.keys)
                                 .pluck(:identifier, :id)
                                 .to_h

    # Bulk create relationships
    puts "\nCreating #{relationships_to_create.size} relationships..."
    relationships_processed = 0
    ActiveRecord::Base.transaction do
      relationships_to_create.each_slice(1000) do |rel_batch|
        rel_records = rel_batch.map do |rel|
          parent_id = identifier_to_id[rel[:parent_identifier]]
          child_id = identifier_to_id[rel[:child_identifier]]
          next unless parent_id && child_id

          {
            parent_id: parent_id,
            child_id: child_id,
            relationship_type: rel[:relationship_type],
            created_at: Time.current,
            updated_at: Time.current
          }
        end.compact

        # Use insert_all to skip validations and callbacks for speed
        OntologyTermRelationship.insert_all(
          rel_records,
          unique_by: [:parent_id, :child_id]
        )
        relationships_processed += rel_batch.size
        print_progress(relationships_processed, relationships_to_create.size, "Relations")
      end
    end
    puts "\n\nOntology table updated successfully!"
  end
end
