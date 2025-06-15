desc "VALIDATE GELLxGENE DATASETS"
task validate_cxg: :environment do
  DatasetValidator.new("CELLxGENE").validate!
end

desc "VALIDATE BGEE DATASETS"
task validate_bgee: :environment do
  DatasetValidator.new("Bgee").validate!
end

desc "VALIDATE ASAP DATASETS"
task validate_asap: :environment do
  DatasetValidator.new("ASAP").validate!
end

desc "VALIDATE SINGLE CELL PORTAL DATASETS"
task validate_scp: :environment do
  DatasetValidator.new("SINGLE CELL PORTAL").validate!
end

desc "Run all validations"
task validate_datasets: :environment do
  tasks_to_run = [
    "validate_cxg",
    "validate_bgee",
    "validate_asap",
    "validate_scp",
  ]

  tasks_to_run.each do |task|
    Rake::Task[task].invoke
  end
end
