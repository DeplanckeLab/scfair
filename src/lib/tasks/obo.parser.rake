require "rake"

def print_progress(current, total, title = "Progress")
  return if total.zero?
  width = 50
  progress = current.to_f / total
  filled = (progress * width).to_i
  empty = width - filled
  percent = (progress * 100).to_i
  print "\r#{title}: [#{'=' * filled}#{' ' * empty}] #{percent}% (#{current}/#{total})"
end

# Normalize OBO identifier to standard format
# v2 OBO format: efo:EFO_0009899 -> Standard format: EFO:0009899
def normalize_identifier(identifier)
  return identifier unless identifier.present?

  # Handle efo:EFO_XXXXXXX -> EFO:XXXXXXX
  if identifier.match?(/^efo:EFO_(\d+)$/i)
    number = identifier.split('_').last
    return "EFO:#{number}"
  end

  identifier
end

namespace :obo do
  desc "Parse .obo file and update Ontology table"
  task :parse, [:file_path] => :environment do |t, args|
    file_path = args[:file_path]

    if file_path.nil?
      puts "Usage: rake obo:parse[file_path]"
      exit
    end

    puts "\nCounting lines..."
    total_lines = File.foreach(file_path).count
    puts "Found #{total_lines} lines"

    terms_to_create = {}
    relationships_to_create = []
    current_term = {}
    current_relationships = []
    line_count = 0

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
            description: current_term[:description],
            synonyms: current_term[:synonyms] || []
          }
          relationships_to_create.concat(current_relationships)
        end
        current_term = { synonyms: [] }
        current_relationships = []
      when /^synonym: "([^"]+)"/
        # Extract synonym text from formats like: synonym: "human" EXACT genbank_common_name []
        current_term[:synonyms] ||= []
        current_term[:synonyms] << $1.strip
      when /^id: (.+)/
        # Accept various identifier formats:
        # - Standard: CL:0000001, UBERON:0001234, EFO:1234567
        # - EFO format: efo:EFO_0000001 (will be normalized to EFO:0000001)
        # - Cellosaurus: CVCL_0001
        # - Underscore only: BAO_0000875
        identifier = $1.strip
        if identifier.match?(/^[A-Za-z][A-Za-z0-9:_]*[0-9_]$/)
          # Normalize to standard format (efo:EFO_XXXX -> EFO:XXXX)
          current_term[:identifier] = normalize_identifier(identifier)
        end
      when /^name: (.+)/
        current_term[:name] = $1.strip
      when /^def: "([^"]+)".*$/
        current_term[:description] = $1.strip
      when /^is_a: ([A-Za-z][A-Za-z0-9:_]*[0-9_])(?:\s|$)/
        current_relationships << {
          child_identifier: current_term[:identifier],
          parent_identifier: normalize_identifier($1.strip),
          relationship_type: 'is_a'
        }
      when /^relationship: part_of ([A-Za-z][A-Za-z0-9:_]*[0-9_])(?:\s|$)/
        current_relationships << {
          child_identifier: current_term[:identifier],
          parent_identifier: normalize_identifier($1.strip),
          relationship_type: 'part_of'
        }
      end
    end
    print_progress(total_lines, total_lines, "Parsing")
    puts "\n"

    if current_term[:identifier].present?
      terms_to_create[current_term[:identifier]] = {
        identifier: current_term[:identifier],
        name: current_term[:name],
        description: current_term[:description],
        synonyms: current_term[:synonyms] || []
      }
      relationships_to_create.concat(current_relationships)
    end

    puts "\nCreating/updating #{terms_to_create.size} terms..."
    terms_processed = 0
    start_time = Time.now

    ActiveRecord::Base.transaction do
      terms_to_create.each_slice(1000) do |terms_batch|
        records = terms_batch.map do |identifier, attributes|
          {
            identifier: attributes[:identifier],
            name: attributes[:name],
            description: attributes[:description],
            synonyms: attributes[:synonyms] || [],
            created_at: Time.current,
            updated_at: Time.current
          }
        end

        OntologyTerm.upsert_all(
          records,
          unique_by: :identifier,
          update_only: [:name, :description, :synonyms]
        )

        terms_processed += records.size

        if terms_processed % 1000 == 0
          elapsed = Time.now - start_time
          rate = terms_processed / elapsed
          remaining = terms_to_create.size - terms_processed
          eta = remaining / rate
          print_progress(terms_processed, terms_to_create.size, "Terms")
          print " | #{rate.round(0)}/s | ETA: #{eta.round(0)}s"
        end
      end
    end

    elapsed = Time.now - start_time
    print_progress(terms_to_create.size, terms_to_create.size, "Terms")
    puts " | Completed in #{elapsed.round(1)}s (#{(terms_to_create.size / elapsed).round(0)}/s)\n"

    puts "\nBuilding identifier mapping..."
    identifier_to_id = {}
    all_identifiers = terms_to_create.keys
    total_identifiers = all_identifiers.size
    processed_identifiers = 0
    
    all_identifiers.each_slice(10000) do |identifier_batch|
      batch_mapping = OntologyTerm.where(identifier: identifier_batch)
                                 .pluck(:identifier, :id)
                                 .to_h
      identifier_to_id.merge!(batch_mapping)
      processed_identifiers += identifier_batch.size
      print_progress(processed_identifiers, total_identifiers, "Mapping") if processed_identifiers % 10000 == 0
    end
    print_progress(total_identifiers, total_identifiers, "Mapping")
    puts "\n"

    puts "\nCreating #{relationships_to_create.size} relationships..."
    relationships_processed = 0
    start_time = Time.now

    relationships_to_create.each_slice(1000) do |rel_batch|
      begin
        ActiveRecord::Base.transaction do
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

          if rel_records.any?
            OntologyTermRelationship.insert_all(
              rel_records,
              unique_by: [:parent_id, :child_id]
            )
          end
        end
        relationships_processed += rel_batch.size

        if relationships_processed % 1000 == 0
          elapsed = Time.now - start_time
          rate = relationships_processed / elapsed
          remaining = relationships_to_create.size - relationships_processed
          eta = remaining / rate
          print_progress(relationships_processed, relationships_to_create.size, "Relations")
          print " | #{rate.round(0)}/s | ETA: #{eta.round(0)}s"
        end
      rescue ActiveRecord::ConnectionFailed, PG::ConnectionBad => e
        puts "\nConnection error, reconnecting and retrying..."
        ActiveRecord::Base.connection.reconnect!
        sleep(1)
        retry
      end
    end

    elapsed = Time.now - start_time
    print_progress(relationships_to_create.size, relationships_to_create.size, "Relations")
    puts " | Completed in #{elapsed.round(1)}s (#{(relationships_to_create.size / elapsed).round(0)}/s)\n"

    puts "\nOntology parsing completed successfully!"
    puts "Total terms processed: #{terms_to_create.size}"
    puts "Total relationships created: #{relationships_to_create.size}"
  end
end
