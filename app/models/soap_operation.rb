# BioCatalogue: app/models/soap_operation.rb
#
# Copyright (c) 2008, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

class SoapOperation < ActiveRecord::Base
  if ENABLE_CACHE_MONEY
    is_cached :repository => $cache
    index :soap_service_id
  end
  
  acts_as_trashable
  
  acts_as_annotatable
  
  acts_as_archived
  
  belongs_to :soap_service
  
  belongs_to :soap_service_port
  
  has_many :soap_inputs,
           :conditions => "soap_inputs.archived_at IS NULL",
           :dependent => :destroy,
           :order => "soap_inputs.name ASC"
           
  has_many :soap_outputs,
           :conditions => "soap_outputs.archived_at IS NULL",
           :dependent => :destroy,
           :order => "soap_outputs.name ASC"
  
  has_many :archived_soap_inputs,
           :class_name => "SoapInput",
           :foreign_key => "soap_operation_id",
           :dependent => :destroy,
           :conditions => "soap_inputs.archived_at IS NOT NULL",
           :order => "soap_inputs.name ASC"
  
  has_many :archived_soap_outputs,
           :class_name => "SoapOutput",
           :foreign_key => "soap_operation_id",
           :dependent => :destroy,
           :conditions => "soap_outputs.archived_at IS NOT NULL",
           :order => "soap_outputs.name ASC"
  
  if ENABLE_SEARCH
    acts_as_solr(:fields => [ :name, :description, :parent_port_type,
                              { :associated_service_id => :r_id } ] )
  end
  
  if USE_EVENT_LOG
    acts_as_activity_logged(:models => { :referenced => { :model => :soap_service } })
  end
  
  def associated_service_id
    BioCatalogue::Mapper.map_compound_id_to_associated_model_object_id(BioCatalogue::Mapper.compound_id_for(self.class.name, self.id), "Service")
  end
  
  def associated_service
    @associated_service ||= Service.find_by_id(associated_service_id)
  end
  
  def preferred_description
    # Either the description from the service description doc, 
    # or the last description annotation.
    
    desc = self.description
    
    if desc.blank?
      desc = self.annotations_with_attribute("description").first.try(:value)
    end
    
    return desc
  end
  
  # This will attempt to copy over as many annotations as possible from this 
  # SoapOperation to another given SoapOperation.
  # 
  # This is useful to copy over, for example, annotations from an archived operation
  # to another that may have been created as a result of a renamed in the WSDL.
  #
  # This includes annotations on inputs and outputs (matched by name), 
  # excluding archived inputs and output on this operation.
  def copy_annotations_to(op_to, culprit)
    return [ ] if op_to.blank? or culprit.blank? or !op_to.is_a?(SoapOperation)
    
    total_annotations = [ ]
    
    self.annotations.each do |ann|
      new_ann = ann.copy(op_to, culprit)
      total_annotations << new_ann unless new_ann.nil?
    end
    
    %w{ inputs outputs }.each do |t|
      eval("self.soap_#{t}").each do |o1|
        o2 = eval("op_to.soap_#{t}.find_by_name(o1.name)")
        unless o2.nil?
          o1.annotations.each do |ann|
            new_ann = ann.copy(o2, culprit)
            total_annotations << new_ann unless new_ann.nil?
          end
        end
      end
    end
    
    return total_annotations
  end
end
