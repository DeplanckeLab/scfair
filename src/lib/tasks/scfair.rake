namespace :scfair do
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
