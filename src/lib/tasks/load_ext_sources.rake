desc "Match dataset URLs with external sources"
task load_ext_sources: :environment do
  puts "Executing..."

  ext_sources = ExtSource.all
  broken_links = []
  
  Dataset.includes(:links).find_each do |dataset|
    dataset.links.each do |link|
      es = nil
      id = nil
      
      ext_sources.each do |ext_source|
        ext_source.url_mask.split(" ").each do |url_mask|
          # Create regex pattern from URL mask
          re = url_mask.gsub(/[\/=\?]/) { |match| "\\" + match }.gsub("\#ID", "(.+?)")
          
          if (m = link.url.match(/^#{re}\/?$/))
            puts "#{link.url} matches #{re} step1 => #{m[1]} #{ext_source.id_regexp}"
            
            if ext_source.id_regexp.present?
              if m[1].match(/#{ext_source.id_regexp}/)
                id = m[1]
                puts "#{link.url} matches #{ext_source.name} step2"
                es = ext_source
                break
              end
            else
              es = ext_source
              break
            end
          end
          break if es
        end
      end
      
      name = "#{es&.name}"
      name << ":#{id}" if id
      puts "Updating... #{link.url} => #{name}"
      link.update(name: name) if es
    end
  end
  
  puts "BROKEN LINKS: "
  puts broken_links.to_json
end
