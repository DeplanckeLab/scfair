require 'json'

puts "Seeding studies..."

def parse_sql_value(value)
  return nil if value == "\\N"
  value
end

begin
  file_path = Rails.root.join("db/data/studies.sql")
  content = File.read(file_path)

  data_lines = content.lines.select { |line| line.match?(/^\d+\t/) }
  
  studies = data_lines.map do |line|
    fields = line.strip.split("\t")
    
    {
      id: fields[0].to_i,
      title: parse_sql_value(fields[1]),
      first_author: parse_sql_value(fields[2]),
      authors: parse_sql_value(fields[3]),
      authors_json: JSON.parse(parse_sql_value(fields[4])),
      abstract: parse_sql_value(fields[5]),
      journal_id: parse_sql_value(fields[6])&.to_i,
      volume: parse_sql_value(fields[7]),
      issue: parse_sql_value(fields[8]),
      doi: parse_sql_value(fields[9]),
      year: parse_sql_value(fields[10])&.to_i,
      comment: parse_sql_value(fields[11]),
      description: parse_sql_value(fields[12]),
      published_at: parse_sql_value(fields[13]),
      created_at: parse_sql_value(fields[14]),
      updated_at: parse_sql_value(fields[15])
    }
  end

  Study.delete_all
  
  Study.insert_all!(studies)
  
  puts "Successfully seeded #{Study.count} studies"
rescue => e
  puts "Error seeding studies: #{e.message}"
  puts e.backtrace
end
