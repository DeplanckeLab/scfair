namespace :scfair do
  desc "setup scfair"
  task setup: :environment do
    puts "Setting up SCFAIR"

    tasks_to_run = [
      "db:seed",
      "api_updates",
      "load_studies",
      "load_ext_sources",
      "validate_datasets",
      "index_db"
    ]

    tasks_to_run.each do |task|
      Rake::Task[task].invoke
    end

    puts "SCFAIR setup completed successfully!"
  end
end
