namespace :compliance_checks do
  desc "Import ASAP standalone compliance checks for all FileResource URLs (ASAP_BASE_URL, DRY_RUN=1, LIMIT=n)"
  task import_from_asap: :environment do
    importer = AsapComplianceCheckImporter.new
    ok = importer.perform
    abort "compliance_checks:import_from_asap finished with errors" unless ok
  end

  desc "Match ASAP Broad SCP catalog downloads to scFAIR datasets, create file_resources, import checks (ASAP_BASE_URL, DRY_RUN=1, LIMIT=n)"
  task import_scp_from_asap: :environment do
    importer = ScpComplianceCheckImporter.new
    ok = importer.perform
    abort "compliance_checks:import_scp_from_asap finished with errors" unless ok
  end
end
