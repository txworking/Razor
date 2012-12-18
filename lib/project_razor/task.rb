 #used for execute a scheme
class ProjectRazor::Task < ProjectRazor::Object
	 include ProjectRazor::Logging

	      attr_accessor :label
	      attr_accessor :enabled
        attr_accessor :policies
        attr_accessor :active_models
        attr_accessor :description
        attr_accessor :status
        attr_accessor :scheme
        attr_accessor :nodes

  def initialize(hash)
    super()
    @_namespace = :task
    @name       = "Task Name : #{uuid}"
    @noun       = :task_name
    from_hash(hash)
  end

  def print_header
    return "UUID", "Label", "status", "Scheme", "Nodes"
  end
    
  def print_items
    temp_nodes = self.nodes
    temp_nodes = ["n/a"] if temp_nodes == [] || temp_nodes == nil
    case @status
    when nil
      status = "U"
    end

    return @uuid, @label, status, @scheme.label, "[#{temp_nodes.join(",")}]"
  end
    
  def print_item_header
     return "UUID", "Label", "status", "Scheme", "Nodes"
  end
    
  def print_item
    temp_nodes = self.nodes
    temp_nodes = ["n/a"] if temp_nodes == [] || temp_nodes == nil
    case @status
    when nil
      status = "U"
    end
    return @uuid, @label, status, @scheme.label, "[#{temp_nodes.join(",")}]"
  end
    

  def line_color
      :white_on_black
  end

  def header_color
      :red_on_black
  end

end
