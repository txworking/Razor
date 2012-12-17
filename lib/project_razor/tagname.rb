class ProjectRazor::Tagname < ProjectRazor::Object
	attr_accessor :name
	
	# init
	def initialize(hash)
		super()
		@_namespace = :tag_name
		@noun       = :tag_name
		@name = "Tag Name : #{uuid}"

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