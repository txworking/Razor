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
    @_namespace    = :task
    @name          = "Task Name : #{uuid}"
    @noun          = :task_name
    @policies      = []
    @nodes         = []
    @active_models = {} 
    @status        = :stopped
    from_hash(hash)
  end

  #TODO status => action
  def fsm
        {
          :stopped => {
            :remove => :removed,
            :update => :started,
            :start => :started},
          :started => {
            :error_catch => :error,
            :complete => :completed,
            :abort => :completed},
          :error => {
            :abort => :completed,
            :retry => :started,
            :ignore => :completed},
          :completed => {
            :remove => :removed,
            :else => :completed}
        }    
  end

  def fsm_action(action, method)
    old_status = @status
    begin
        if fsm[@status][action] != nil
            @status = fsm[@status][action]
        else
          @status = fsm[@status][:else]
        end
    rescue => e
        logger.error "FSM ERROR: #{e.message}"
        raise e
    end
    logger.debug "Task status change from #{old_status} to #{@status}"

  end

  def print_header
    return "UUID", "Label", "Status", "Scheme", "Nodes"
  end
    
  def print_items
    temp_nodes = self.nodes
    temp_nodes = ["n/a"] if temp_nodes == [] || temp_nodes == nil
    case @status
    when nil
      status = "U"
    when "stopped"
      status = "P"
    when "started"
      status = "S"
    when "error"
      status = "E"
    when "completed"
      status = "C"
    else
      status = "U"
    end

    return @uuid, @label, status, @scheme.label, "[#{temp_nodes.join(",")}]"
  end
    
  def print_item_header
     return "UUID", "Label", "Status", "Scheme", "Nodes"
  end
    
  def print_item
    temp_nodes = self.nodes
    temp_nodes = ["n/a"] if temp_nodes == [] || temp_nodes == nil
    return @uuid, @label, @status, @scheme.label, "[#{temp_nodes.join(",")}]"
  end
    

  def line_color
      :white_on_black
  end

  def header_color
      :red_on_black
  end

  def update_status(action, active_model)
    if active_model
      final_state = active_model.model.final_state
      case active_model.model.current_state
      when :error_catch, :timeout_error, :broker_fail
        fsm_action(:error_catch)
      when final_state
        self.active_models[active_model.uuid] = final_state
        self.active_models.each do |k,v|
          return nil if v != final_state
        end
        fsm_action(:complete)
      end        
    elsif action
      fsm_action(action)
    end
    
  end

end
