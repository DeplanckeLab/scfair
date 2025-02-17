namespace :fix do
  desc "Fix organisms table to address duplicate and missing records based on new parsing rules"
  task organisms: :environment do
    puts "Starting organisms table fix..."

    ################################################################################
    # Fix 1: Mus musculus (tax_id: 10090) – keep only the most generic record.
    #
    # Expected record:
    #   Name: Mus musculus
    #   Short name: Mouse
    #   Taxonomy ID: 10090
    ################################################################################
    mus_records = Organism.where(tax_id: 10090, name: "Mus musculus")
    if mus_records.count > 1 || (mus_records.count == 1 && mus_records.first.short_name != "Mouse")
      generic_mus = mus_records.find_by(short_name: "Mouse")
      if generic_mus.nil?
        generic_mus = mus_records.first
        generic_mus.update!(short_name: "Mouse")
        puts "Updated Mus musculus record (ID #{generic_mus.id}) with short_name 'Mouse'."
      end

      duplicate_ids = mus_records.where.not(id: generic_mus.id).pluck(:id)
      if duplicate_ids.any?
        Organism.where(id: duplicate_ids).destroy_all
        puts "Removed duplicate Mus musculus records; kept record ID #{generic_mus.id}."
      end
    else
      puts "Mus musculus records are already fixed."
    end

    ################################################################################
    # Fix 2: Gorilla – if an organism with tax_id 9593 (input uses id 9593) is missing,
    # create it. The seeds already include:
    #   { name: "Gorilla gorilla gorilla", short_name: "Gorilla", tax_id: 9595 }
    #
    # We need also:
    #   { name: "Gorilla gorilla", short_name: "Gorilla", tax_id: 9593 }
    ################################################################################
    gorilla_9593 = Organism.find_by(tax_id: 9593, name: "Gorilla gorilla")
    if gorilla_9593.nil?
      new_ext_id = (Organism.maximum(:external_reference_id) || 0) + 1
      gorilla_9593 = Organism.create!(
        external_reference_id: new_ext_id,
        name: "Gorilla gorilla",
        short_name: "Gorilla",
        tax_id: 9593
      )
      puts "Created new Gorilla record with tax_id 9593 (ID #{gorilla_9593.id})."
    else
      puts "Gorilla record with tax_id 9593 already exists (ID #{gorilla_9593.id})."
    end

    ################################################################################
    # Fix 3: Naked mole rat – for tax_id 10181, keep only one record and change
    # the short name to "Naked mole-rat".
    #
    # Expected record:
    #   Name: Heterocephalus glaber
    #   Short name: Naked mole-rat
    #   Taxonomy ID: 10181
    ################################################################################
    nmr_records = Organism.where(tax_id: 10181, name: "Heterocephalus glaber")
    if nmr_records.exists?
      generic_nmr = nmr_records.first
      generic_nmr.update!(short_name: "Naked mole-rat")
      duplicate_nmr_ids = nmr_records.where.not(id: generic_nmr.id).pluck(:id)
      if duplicate_nmr_ids.any?
        Organism.where(id: duplicate_nmr_ids).destroy_all
        puts "Removed duplicate Naked mole rat records (IDs: #{duplicate_nmr_ids.join(", ")})."
      end
      puts "Naked mole rat fixed; kept record ID #{generic_nmr.id}."
    else
      puts "No Naked mole rat records found with tax_id 10181."
    end

    ################################################################################
    # Fix 4: Sus scrofa domesticus – for CELLxGENE, input uses tax_id 9825.
    # Rule: Keep only one record and change its short name to "Pig".
    #
    # Expected record:
    #   Name: Sus scrofa domesticus
    #   Short name: Pig
    #   Taxonomy ID: 9825
    #
    # In the database there might be a record with tax_id 9823 and name "Sus scrofa".
    # If no record exists with tax_id 9825 and the proper name, update a candidate.
    ################################################################################
    ssc_records = Organism.where(tax_id: 9825, name: "Sus scrofa domesticus")
    unless ssc_records.exists?
      candidate = Organism.where(tax_id: 9823)
                 .where("lower(name) LIKE ?", "sus scrofa%")
                 .first
      if candidate
        candidate.update!(name: "Sus scrofa domesticus", tax_id: 9825, short_name: "Pig")
        puts "Updated candidate Sus scrofa record (ID #{candidate.id}) to 'Sus scrofa domesticus' with tax_id 9825 and short_name 'Pig'."
        ssc_records = Organism.where(tax_id: 9825, name: "Sus scrofa domesticus")
      else
        puts "No candidate Sus scrofa record found for update."
      end
    end

    if ssc_records.exists?
      generic_ssc = ssc_records.first
      generic_ssc.update!(short_name: "Pig")
      duplicate_ssc_ids = ssc_records.where.not(id: generic_ssc.id).pluck(:id)
      if duplicate_ssc_ids.any?
        Organism.where(id: duplicate_ssc_ids).destroy_all
        puts "Removed duplicate Sus scrofa domesticus records (IDs: #{duplicate_ssc_ids.join(", ")})."
      end
      puts "Sus scrofa domesticus fixed; kept record ID #{generic_ssc.id}."
    end

    puts "Organisms table fix completed."
  end
end
