class ProjectRazor::Scheme < ProjectRazor::Object
		# init
		attr_accessor :label
		attr_accessor :model_uuid
		attr_accessor :broker_uuid
		attr_accessor :nodes_uuid

		def initialize(hash)
			super()
			@_namespace = :scheme
			@noun       = :scheme
			@name = "Scheme : #{uuid}"

			from_hash(hash)
		end
		def print_header
			return "UUID", "Label", "Model", "Broker", "Nodes"
		end
			
		def print_items
			return @uuid, @label, @model_uuid, @broker_uuid, "[#{@nodes_uuid.join(",")}]"
		end
			
		def print_item_header
			return "UUID", "Label", "Model", "Broker", "Nodes"
		end
			
		def print_item
			return @uuid, @label, @model_uuid, @broker_uuid, "[#{@nodes_uuid.join(",")}]"
		end
			

		def line_color
		    :white_on_black
		end

		def header_color
		    :red_on_black
		end


end
