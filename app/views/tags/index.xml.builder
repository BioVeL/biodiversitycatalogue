# BioCatalogue: app/views/tags/index.xml.builder
#
# Copyright (c) 2008-2009, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

# <?xml>
xml.instruct! :xml

# <services>
xml.tag! "tags", 
         xlink_attributes(uri_for_collection("tags", :params => params)), 
         xml_root_attributes do
  
  # <parameters>
  xml.parameters do
    
    # <limit>
    xml.limit params[:limit]
    
  end
  
  # <statistics>
  xml.statistics do
    
    # <itemCounts>
    xml.itemCounts do 
      
      # <total>
      xml.total @tags.length      
      
    end
    
  end
  
  # <results>
  xml.results do
    
    # <tag> *
    @tags.each do |t|
      xml.tag t['name'], 
              xlink_attributes(BioCatalogue::Tags.generate_tag_show_uri(t['name']), :title => xlink_title(t, "Tag")),
              { :totalItemsCount => t['count'] } 
    end
    
  end
  
  # <related>
  xml.related do
    
  end
  
end