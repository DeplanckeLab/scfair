class CustomFetch
  class << self

    def format_author e
      if e['family']
        fname = (e['family'].upcase == e['family']) ? e['family'].downcase.split(" ").map{|e| e.capitalize}.join(" ") : e['family']
        if m = fname.match(/^(O\'|Ma?c|Fitz)(.+)/) #or  m = fname.match(/^(Fitz)(.+)/) or  m = fname.match(/^(Ma?c)(.+)/)                                                                                                
          fname = m[1] + m[2].capitalize
        end
        
        h_author = {
          'initials' => e['given'] ? e['given'].force_encoding(Encoding::ISO_8859_1).encode(Encoding::UTF_8).gsub(/[a-z]+/, "") : nil,
          'fname' => e['given'] ? e['given'].force_encoding(Encoding::ISO_8859_1).encode(Encoding::UTF_8) : nil,
          'lname' => fname.force_encoding(Encoding::ISO_8859_1).encode(Encoding::UTF_8), #(e['family'].upcase == e['family']) ? e['family'].downcase.capitalize : e['family'],                                           
          'aff_ids' => []
        }
      end
      return h_author
    end

    
    def doi_info doi
      
      h_article = {}
      
      cmd = "wget -qO - 'http://api.crossref.org/works/#{doi}'"
      
      data_json = `#{cmd}`
      h_json = Basic.safe_parse_json(data_json, {})
      
      m = h_json["message"]
      
      j = nil
      if m

        j_name = nil
#        puts m["institution"].to_json                                                                                                                     
        if journals = m['container-title'] and journals[0]
          j_name = journals[0]
        elsif inst = m["institution"] and (inst = inst.is_a?(Array) ? inst.first : inst) and inst["name"]
          j_name = inst["name"]
        end

        if j_name
          j = Journal.where(:name => j_name).first
          if !j
            j = Journal.new(:name => j_name)
            j.save
          end
        end
        
        
        title = (m['title']) ? m['title'][0] : ''
        
        if m2 = title.match(/\[sub\s*(\d+)\]/)
          
          title.gsub!(/\[sub\s*(\d+)\]/, "<sub>/1</sub>")
        end
        
        authors =  (m['author']) ? m['author'].map{|e|
                                     format_author(e)
                                   }.compact : []
        #        puts authors.to_json                                                                                                                              
        fa = (authors and authors.size > 0) ? authors.first : nil
        
        title.gsub!(/\s*<i>/, " <i>")
        title.gsub!(/<\/i>\s+/, "<i> ")
        h_article = {
          :doi => doi,
          :title => title,
          :authors => (fa) ? ("#{fa['lname']}" + ((authors.size > 1) ?  " et al." : '')) : nil ,
          :authors_json => authors.to_json,
          :first_author => (fa) ? fa['lname'] : nil,
          :journal_id => (j) ? j.id : nil,
          :volume => m['volume'],
          :issue => m['issue'],
          :year => (m['issued']) ? m['issued']['date-parts'][0][0] : nil,                                                                               
          :published_at => (m['journal-issue'] and e = m['journal-issue']['published-print'] and e2 = e["date-parts"] and d = e2[0]) ? Time.new(d[0], d[1] || 1, d[2] || 1) : ((m['issued'] and  e3 = m['issued']["date-parts"] and d2 = e3[0]) ? Time.new(d2[0], d2[1] || 1, d2[2] || 1) : nil)
        }
        if m['issued'] and  e3 = m['issued']["date-parts"] and d2 = e3[0]
        end
                
      end
      puts h_article
      return h_article
      
    end
    
    
    
  end
end
