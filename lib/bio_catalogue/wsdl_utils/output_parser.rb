#!/usr/bin/ruby
#
# lib/bio_catalogue/wsdl_utils/output_parser.rb
#
# Copyright (c) 2009-2010, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

# A Helper module to parse the output generated by the WSDLUtils parse function
# The output of the parse function from the WSDLUtil library is converted into an
# REXML document. The document is then transformed into a ruby hash by classes in this
# helper module

# Note 
# 'documentation' tags are mapped to the 'description' keys of the resulting hash
# e.g operation['description'] = text between the documentation tags for an operation

module BioCatalogue
  module WsdlUtils
    module OutputParser
    
      class Service
        
        attr_accessor :service_element
        
        def initialize(service_element)
          @service_element = service_element
        end
        
        def parse
          service_data = {"ports" => [], "operations" => []}
          service_data["name"] = @service_element.attributes["name"]
  #        @service_element.elements.each("description") do |desc|
  #          service_data["description"] = desc.text
  #        end
          @service_element.elements.each("namespace") do |ns|
            service_data["namespace"] = ns.text
          end
          @service_element.elements.each("documentation") do |doc|
            #service_data["documentation"] = doc.text
            service_data["description"] = doc.text
          end
          
           @service_element.elements.each("ports/port") do |port|
            service_data["ports"] << Port.new(port).parse
          end
          
          @service_element.elements.each("ports/port/operations/operation") do |operation|
            service_data["operations"] << Operation.new(operation).parse
          end
          
          # set the location of the first port as the default endpoint
          service_data["endpoint"] = set_default_endpoint(service_data["ports"])
          return service_data
        end
        
        
        def set_default_endpoint(ports)
          endpoint = nil
          unless ports.empty?
            endpoint = ports[0]["location"]
          end
          return endpoint
        end
        
      end # end service
      
      class Port
        attr_accessor :port_element
        
        def initialize(port_element)
          @port_element = port_element
        end
        
        def parse
          port_data = {}
          port_data["name"] = @port_element.attributes["name"]
          @port_element.elements.each("protocol") do |prot|
            port_data["protocol"] = prot.text
          end
          @port_element.elements.each("style") do |style|
            port_data["style"] = style.text
          end
          @port_element.elements.each("location") do |loc|
            port_data["location"] = loc.text
          end
          
          return port_data
        end
      end
     
      class Operation
        
        attr_accessor :operation_element
          
        def initialize(operation_element)
          @operation_element = operation_element
        end
          
        def parse
          operation_data = { "inputs" => [], "outputs" => [] }
          operation_data["name"] = @operation_element.attributes["name"]
  #        @operation_element.elements.each("description") do |desc|
  #          operation_data["description"] = desc.text
  #        end
          @operation_element.elements.each("action") do |action|
            operation_data["action"] = action.text
          end
          @operation_element.elements.each("documentation") do |doc|
            #operation_data["documentation"] = doc.text
            operation_data["description"] = doc.text
          end
          @operation_element.elements.each("type") do |type|
            operation_data["operation_type"] = type.text
          end
          operation_data["parent_port_type"] = @operation_element.parent.parent.attributes["name"]
          
          
          #messages for this operation
          @operation_element.elements.each("messages") do |messages|
            operation_data["operation_input"] = Message.new(messages, "inputmessage").parse
            operation_data["operation_output"] = Message.new(messages, "outputmessage").parse           
          end
          
          unless operation_data["operation_input"].nil?
            operation_data["operation_input"]["parts"].each do |p|
              #p["types"].each do |t|
              #  operation_data["inputs"] << t
              #end
              operation_data["inputs"] << p
            end
            #Note! removing the hierachical input data for testing
            operation_data.delete("operation_input")
          end
          
          unless operation_data["operation_output"].nil?
            operation_data["operation_output"]["parts"].each do |p|
              #p["types"].each do |t|
              #  operation_data["outputs"] << t
              #end
              operation_data["outputs"] << p
            end
            #Note! removing the hierachical output data for testing
            operation_data.delete("operation_output")
          end
          
          return operation_data
        end
      end
      
      class Message
        
        attr_accessor :message_element
        attr_accessor :message_type
        attr_accessor :use_formatters
        
        def initialize(message_element, message_type)
          @message_element  = message_element
          @message_type     = message_type
          @use_formatters   = true
          
          begin
            require 'rexml/formatters/default'
          rescue LoadError => ex
            @use_formatters = false
            Rails.logger.error("could not load rexml/formatters/default")
            Rails.logger.error(ex.backtrace.join("\n"))
          end
        end
        
        # the number of inputs = the number of message parts
        # complex types are expanded and stored in 
        # 'computational_type_details' attribute
        def parse
          message_data ={"parts" => [] }
          @message_element.elements.each(@message_type) do |message|
            message_data["name"] = message.attributes["name"]
            message.elements.each("parts/part") do |part|
              #part_data = {"types" => [] }
              part_data = {}
              part_data["name"] = part.attributes["name"]
              part.elements.each("type") do |type|
                part_data["computational_type"] = type.attributes["name"]
                # complex type
                if type.has_elements?
                  type_details = ''
                  
                  # when rexml/formatter package is not available like ruby 1.8.5 
                  # use element.write method is used to 
                  # convert element to its string equivalent
                  if @use_formatters
                    REXML::Formatters::Default.new().write(type, type_details)
                  else
                    type.write(type_details)
                  end
                  part_data["computational_type_details"]= Hash.from_xml(type_details)
                end
              end
              message_data["parts"] << part_data
            end  
          end
          return message_data
        end
        
        def parse_old
          message_data ={"parts" => [] }
          @message_element.elements.each(@message_type) do |message|
            message_data["name"] = message.attributes["name"]
            message.elements.each("parts/part") do |part|
              part_data = {"types" => [] }
              type_env = nil
              inner_types = []
              part_data["name"] = part.attributes["name"]
              part.elements.each("type") do |type|
                type_env = type
                inner_types << type
              end
              while type_env.has_elements?
                inner_types = [] 
                type_env.elements.each("type") do |t|             
                  inner_types << t
                  type_env = t
                  #puts "inner type"
                end
               # stop at the outer set of types that makeup the input of this operation 
               break if inner_types.length > 1  
              end
              
              if inner_types.length == 1  # got a leave node of the element tree
                type_data ={}
                parent_element = inner_types[0].parent
                if parent_element.attributes["name"] =="restriction"
                  parent_element = parent_element.parent 
                end
                
                type_data["name"] = parent_element.attributes["name"]
                parent_element.elements.each("documentation") do |doc|
                  #type_data["documentation"] = doc.text
                  type_data["description"] = doc.text
                end
                type_data["computational_type"] = inner_types[0].attributes["name"]
                
                part_data["types"] << type_data
              end
              
              # multiple inputs/outputs for this operation
              if inner_types.length > 1
                inner_types.each do |itype|
                  type_data = {}
                  
                  type_data["name"] = itype.attributes["name"]
                  itype.elements.each("documentation") do |doc|
                    #type_data["documentation"] = doc.text
                    type_data["description"] = doc.text
                  end
                  unless itype.elements.to_a("type").length > 1
                    itype.elements.each("type") do |iitype|
                      type_data["computational_type"] = iitype.attributes["name"]
                    end
                  end
                
                  part_data["types"] << type_data
                  
                end
              end
              
              #pp inner_types
              message_data["parts"] << part_data
            end
          end
          
          return message_data
        end
         
      end   
      
    end
  end
end
