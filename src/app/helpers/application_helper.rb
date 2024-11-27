module ApplicationHelper

  def extract_domain(url)
    return nil if url.blank?
    URI.parse(url).host.gsub(/^www\./, "")
  rescue URI::InvalidURIError
    nil
  end

  def ontology_link_generator(type, id)
    id = id.sub ":", "_" # necessary beacause the url uses _ instead of : in the id                  
    url = "https://www.ebi.ac.uk/ols4/ontologies/#{type}/classes/http%253A%252F%252Fpurl.obolibrary.org%252Fobo%252F#{id}"
    return(url)
  end
  
  def display_study s
    html = [((s and s.first_author) ? s.first_author : nil), ((s and s.year) ? s.year.to_s : nil)].compact.join(", ")
    return html
  end

  def display_nber_cells n
    return Basic.format_number_with_apostrophes(n)
  end
  
  def display_field f, d, h
    vals = d[f] #.uniq ### why to put a uniq? should be already uniq no?
    html = ''
    if vals.length > 1 
      
      list = []
      for i in (0 .. vals.length - 1)
        case f
         when :tissue
           list.push link_to vals[i], "#{ontology_link_generator "uberon", d[:tissue_uberon][i]}", target: "_blank"
         when :developmental_stage
           type =  d[:developmental_stage_id][i].split(":")[0].downcase
           list.push link_to vals[i], "#{ontology_link_generator type, d[:developmental_stage_id][i]}", target: "_blank"
         else
           list.push vals[i]
        end
      end

      list.uniq!
      html += "<span class='dropdown-toggle pointer' data-bs-toggle='dropdown' aria-expanded='false'>"
      html += "<i> #{list.size} #{h[f][:label].to_s.downcase.pluralize}</i>"
      html += "</span><ul class='dropdown-menu'>"
      
      list.each do |e|
        html += "<li class='px-2 py-1'>"
        html += e
        html += " </li>"
      end
      
      html += "</ul>"
       
    else

      if !(vals.length == 0)                                                                                                                   
        empty = (d[f][0].nil?) ? true : false                                                                                               
        #   html += "<td class='text-center " + ((empty) ? "bg-light": "" ) + "'>"
        case f                                                                                                                                        
        when :tissue                                                                                                                               
          html += "<i>#{h[f][:label].to_s.downcase}</i>: " + link_to(d[f][0], "#{ontology_link_generator "uberon", d[:tissue_uberon][0]}", target: "_blank")                             
        when :developmental_stage                                                                                                                       
          type =  d[f][0].split(":")[0].downcase                                                                                         
          html +=  "<i>#{h[f][:label].to_s.downcase}</i>: " + link_to(d[f][0], "#{ontology_link_generator type, d[:developmental_stage_id][0]}", target: "_blank")                                 
          else
          html += "<i>#{h[f][:label].to_s.downcase}</i>: " + d[f][0]                                                                                                                      
        end   
      #else                                                                                                                                                           
      #  html += "<td class='bg-light'>                                                                                                                                          
      #                      </td>"
      end             
      
    end
    return html
    
  end
  
end
