require "rake"

namespace :obo do
  desc "Parse .obo file and update Ontology table with adjacency lists"
  task :parse, [:file_path] => :environment do |t, args|
    file_path = args[:file_path]

    if file_path.nil?
      puts "Usage: rake obo:parse[file_path]"
      exit
    end

    identifier_to_name = {}
    identifier_to_description = {}
    children = Hash.new { |hash, key| hash[key] = [] }
    parents = Hash.new { |hash, key| hash[key] = [] }

    current_term = {}
    current_relationships = []

    File.foreach(file_path) do |line|
      line.chomp!
      
      case line
      when "[Term]"
        if current_term[:identifier].present?
          process_term(current_term, current_relationships, identifier_to_name, children, parents)
          if current_term[:description].present?
            identifier_to_description[current_term[:identifier]] = current_term[:description]
          end
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
        current_relationships << { type: 'is_a', target: $1.strip }
      when /^relationship: part_of ([A-Za-z]+:\d+)/
        current_relationships << { type: 'part_of', target: $1.strip }
      end
    end

    if current_term[:identifier].present?
      process_term(current_term, current_relationships, identifier_to_name, children, parents)
      if current_term[:description].present?
        identifier_to_description[current_term[:identifier]] = current_term[:description]
      end
    end

    identifier_to_name.each do |identifier, name|
      next unless identifier.present?
      
      child_list = children[identifier].uniq.presence
      parent_list = parents[identifier].uniq.presence
      child_list = child_list.join(',') if child_list
      parent_list = parent_list.join(',') if parent_list

      puts "add/update ontology term #{identifier}"
      ontology_record = OntologyTerm.find_or_initialize_by(identifier: identifier)
      ontology_record.update(
        name: name,
        description: identifier_to_description[identifier],
        children: child_list,
        parents: parent_list
      )
    end

    puts "Ontology table updated with adjacency lists successfully."
  end

  private

  def process_term(term, relationships, identifier_to_name, children, parents)
    identifier = term[:identifier]
    return unless identifier.present?

    name = term[:name].to_s.strip.presence
    identifier_to_name[identifier] = name

    relationships.each do |rel|
      if rel[:type] == 'is_a' || rel[:type] == 'part_of'
        parent_id = rel[:target]
        next if parent_id == identifier
        
        children[parent_id] << identifier
        parents[identifier] << parent_id
      end
    end
  end
end
