namespace :scfair do
  desc "Reset failed datasets, re-import from APIs, validate, reindex Elasticsearch (run after loading ontologies)"
  task reprocess_failed_datasets: :environment do
    failed_ids = Dataset.where(status: :failed).pluck(:id)
    if failed_ids.empty?
      puts "No failed datasets to reprocess."
    else
      puts "Resetting #{failed_ids.size} failed datasets to processing and clearing parser_hash..."
      Dataset.skip_indexing = true
      Dataset.where(id: failed_ids).find_each do |dataset|
        dataset.update!(status: :processing, parser_hash: "")
      end

      puts "Running api_updates..."
      Rake::Task["api_updates"].invoke

      puts "Running validate_datasets..."
      Rake::Task["validate_datasets"].invoke

      Dataset.skip_indexing = false
      puts "Running index_db..."
      Rake::Task["index_db"].invoke

      puts "Done. Dataset counts by status:"
      puts Dataset.group(:status).count.inspect
    end
  end

  desc "setup scfair"
  task setup: :environment do
    puts "Setting up SCFAIR"

    Dataset.skip_indexing = true

    tasks_to_run = [
      "db:seed",
      "api_updates",
      "load_studies",
      "load_ext_sources",
      "validate_datasets"
    ]

    tasks_to_run.each do |task|
      Rake::Task[task].invoke
    end

    Dataset.skip_indexing = false
    Rake::Task["index_db"].invoke

    puts "SCFAIR setup completed successfully!"
  end
end
