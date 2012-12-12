class ProjectRazor::Region < ProjectRazor::Object
	attr_accessor :name

	def initialize(hash)
		super()
		@_namespace = :region
		@name       = "Region Name : #{uuid}"
		@noun       = :region_name
		from_hash(hash)
	end

	def print_header
		return "UUID", "Name"
	end
		
	def print_items
		return @uuid, @name
	end
		
	def print_item_header
		return "UUID", "Name"
	end
		
	def print_item
		return @uuid, @name
	end
		

	def line_color
	    :white_on_black
	end

	def header_color
	    :red_on_black
	end


end