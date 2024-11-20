desc "Load or update studies from dataset DOIs"
task load_studies: :environment do
  puts "Loading studies from dataset DOIs..."

  stats = { total: 0, found: 0, errors: 0 }

  dois = Dataset.where.not(doi: [nil, ""]).pluck(:doi).uniq
  
  dois.each do |doi|
    stats[:total] += 1
    print "Processing DOI #{stats[:total]}/#{dois.count}: #{doi}"

    begin
      metadata = CustomFetch.doi_info(doi)

      if metadata.present? && metadata[:first_author].present? && metadata[:title].present?
        stats[:found] += 1

        study = Study.find_or_initialize_by(doi: doi)
        study.assign_attributes(metadata)
        
        if study.new_record?
          puts " - Creating new study"
        else
          puts " - Updating existing study"
        end

        study.save!
      else
        puts " - Insufficient metadata found"
        stats[:errors] += 1
      end

    rescue => e
      puts " - Error: #{e.message}"
      stats[:errors] += 1
    end
  end

  puts "Total DOIs processed: #{stats[:total]}"
  puts "Studies created/updated: #{stats[:found]}"
  puts "Errors encountered: #{stats[:errors]}"
end
