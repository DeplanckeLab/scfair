desc "UPDATE GELLxGENE DATASETS"
task update_cxg: :environment do
  parser = CellxgeneParser.new

  if parser.perform
    puts "CELLxGENE parsing completed successfully!"
  else
    puts "CELLxGENE parsing encountered errors:"
    puts parser.errors.join("\n")
  end

  if parser.warnings.any?
    puts "\nWarnings:"
    puts parser.warnings.uniq.join("\n")
  end
end

desc "UPDATE BGEE DATASETS"
task update_bgee: :environment do
  parser = BgeeParser.new

  if parser.perform
    puts "BGEE parsing completed successfully!"
  else
    puts "BGEE parsing encountered errors:"
    puts parser.errors.join("\n")
  end
end

desc "UPDATE ASAP DATASETS"
task update_asap: :environment do
  parser = AsapParser.new

  if parser.perform
    puts "ASAP parsing completed successfully!"
  else
    puts "ASAP parsing encountered errors:"
    puts parser.errors.join("\n")
  end
end

desc "INDEX DB WITH SOLR"
task index_db: :environment do
  Rake::Task["sunspot:reindex"].invoke
end

desc "Run all required tasks sequentially"
task api_updates: :environment do
  # Define the tasks you want to run sequentially
  tasks_to_run = [
    "update_cxg",
    "update_bgee",
    "update_asap",
    "index_db",
  ]

  tasks_to_run.each do |task|
    Rake::Task[task].invoke
  end
end
