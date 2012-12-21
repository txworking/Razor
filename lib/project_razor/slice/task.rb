require 'json'

module ProjectRazor
	class Slice
		class Task < ProjectRazor::Slice

			def create_command(command)
		        return	{
				    :default                        => "throw_missing_uuid_error",
		            ["--help", "-h"]                => "task_help",
		            /^(?!^(all|\-\-help|\-h|\{\}|\{.*\}|nil)$)\S+$/ => {
		                [/^\{.*\}$/]                    => command,
		                :default                        => command,
		                :else                           => "throw_syntax_error"
		            }
		        }
		    end			

			def initialize(args)
				super(args)
		        @hidden          = false
		        @slice_name      = "Task"

		        # get the slice commands map for this slice (based on the set
		        # of commands that are typical for most slices)
		        @slice_commands = get_command_map("task_help",
		                                          "get_all_tasks",
		                                          "get_task_by_uuid",
		                                          "add_task",
		                                          "update_task",
		                                          "remove_all_tasks",
		                                          "remove_task_by_uuid")
		        # and add any additional commands specific to this slice
		        @slice_commands[:get].delete(/^(?!^(all|\-\-help|\-h|\{\}|\{.*\}|nil)$)\S+$/)
		        @slice_commands[:get][:else] = "get_task_by_uuid"
		        
		        task_commands = {
					:start  => create_command("start_task"),
					:retry  => create_command("retry_task"),
					:ignore => create_command("ignore_task"),
					:abort  => create_command("abort_task")
		        }
				@slice_commands.merge! task_commands
			end


			def task_help
		        if @prev_args.length > 1
		          command = @prev_args.peek(1)
		          begin
		            # load the option items for this command (if they exist) and print them
		            option_items = load_option_items(:command => command.to_sym)
		            print_command_help(@slice_name.downcase, command, option_items)
		            return
		          rescue
		          end
		        end
		        # if here, then either there are no specific options for the current command or we've
		        # been asked for generic help, so provide generic help
		        puts get_task_help
			end

			def get_task_help
		        return ["Task Slice:".red,
		                "Used to view, create, update, and remove tasks.".red,
		                "Task commands:".yellow,
		                "\trazor task [get] [all]                      " + "View all tasks".yellow,
		                "\trazor task [get] (UUID)                     " + "View a specific task".yellow,
		                "\trazor task add (options...)                 " + "Create a new task".yellow,
		                "\trazor task update (UUID) (options...)       " + "Update an existing task".yellow,
		                "\trazor task remove (UUID)|all                " + "Remove existing task(s)".yellow,
		                "\trazor task --help|-h                        " + "Display this screen".yellow].join("\n")
				
			end

			def get_all_tasks
		        @command = :get_all_tasks
		        # if it's a web command and the last argument wasn't the string "default" or "get", then a
		        # filter expression was included as part of the web command
		        @command_array.unshift(@prev_args.pop) if @web_command && @prev_args.peek(0) != "default" && @prev_args.peek(0) != "get"
		        # Get all task instances and print/return
		        print_object_array get_object("tasks", :task), "Tasks", :style => :table
			end

			def get_task_by_uuid
		        @command = :get_task_by_uuid
		        # the UUID is the first element of the @command_array
		        task_uuid = @command_array.first
		        task = get_object("get_task_by_uuid", :task, task_uuid)
		        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Task with UUID: [#{task_uuid}]" unless task && (task.class != Array || task.length > 0)
		        print_object_array [task], "", :success_type => :generic
			end

			def add_task
		        @command = :add_task
		        includes_uuid = false
		        # load the appropriate option items for the subcommand we are handling
		        option_items = load_option_items(:command => :add)
		        # parse and validate the options that were passed in as part of this
		        # subcommand (this method will return a UUID value, if present, and the
		        # options map constructed from the @commmand_array)
		        tmp, options = parse_and_validate_options(option_items, "razor task add (options...)", :require_all)
		        includes_uuid = true if tmp && tmp != "add"
		        # check for usage errors (the boolean value at the end of this method
		        # call is used to indicate whether the choice of options from the
		        # option_items hash must be an exclusive choice)
		        check_option_usage(option_items, options, includes_uuid, false)
		        # create a new task using the options that were passed into this subcommand,
		        # then persist the task object
		        setup_data
		        task = ProjectRazor::Task.new({"@label" => options[:label]})
       			scheme = get_object("scheme_by_uuid", :scheme, options[:scheme_uuid])
       			raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Scheme UUID [#{options[:scheme_uuid]}]" unless scheme && (scheme.class != Array || scheme.length > 0)
		        task.scheme = scheme 
		        raise(ProjectRazor::Error::Slice::CouldNotCreate, "Could not create Task") unless task
		        #TODO
		        @data.persist_object(task)
		        print_object_array([task], "", :success_type => :created)
			end

			def update_task
				@command = :update_task
		        includes_uuid = false
		        # load the appropriate option items for the subcommand we are handling
		        option_items = load_option_items(:command => :update)
		        # parse and validate the options that were passed in as part of this
		        # subcommand (this method will return the options map constructed
		        # from the @commmand_array)
		        task_uuid, options = parse_and_validate_options(option_items, "razor task update (UUID) (options...)", :require_one)
		        includes_uuid = true if task_uuid
		        # check for usage errors (the boolean value at the end of this method
		        # call is used to indicate whether the choice of options from the
		        # option_items hash must be an exclusive choice)
		        check_option_usage(option_items, options, includes_uuid, false)
		        # get the task to update
		        task = get_object("task_with_uuid", :task, task_uuid)
		        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Task with UUID: [#{task_uuid}]" unless task && (task.class != Array || task.length > 0)
		        # check status
		        raise ProjectRazor::Error::Slice::InvalidCommand, "Tash has been started [#{task.uuid}]" unless task.fsm[task.status][:update]
		        task.label = options[:label] if options[:label]
				if options[:scheme_uuid]
          			scheme = get_object("scheme_by_uuid", :scheme, options[:scheme_uuid])
          			raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Scheme UUID [#{options[:scheme_uuid]}]" unless scheme && (scheme.class != Array || scheme.length > 0)
          		end
		        task.scheme = scheme if options[:scheme_uuid]
		        #TODO 
				task.enabled       = false
		        raise ProjectRazor::Error::Slice::CouldNotUpdate, "Could not update Task [#{task.uuid}]" unless task.update_self
		        print_object_array [task], "", :success_type => :updated				
			end

			def remove_all_tasks
		        @command = :remove_all_tasks
		        raise ProjectRazor::Error::Slice::MethodNotAllowed, "Cannot remove all Tasks via REST" if @web_command
		        tasks = @data.fetch_all_objects(:task)
		        tasks.each do |task|
		        	binding.pry
		        	# check status
		        	raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove Uncompleted Task #{task.uuid}" unless task.fsm[task.status][:remove]
		        end
		        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove all Tasks" unless @data.delete_all_objects(:task)
		        slice_success("All Tasks removed", :success_type => :removed)
			end

			def remove_task_by_uuid
		        @command = :remove_task_by_uuid
		        # the UUID was the last "previous argument"
		        task_uuid = get_uuid_from_prev_args
		        task = get_object("task_with_uuid", :task, task_uuid)
		        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Task with UUID: [#{task_uuid}]" unless task && (task.class != Array || task.length > 0)
		        # check status
	        	raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove Uncompleted Task [#{task.uuid}]" unless task.fsm[task.status][:remove]
		        setup_data
		        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove Task [#{task.uuid}]" unless @data.delete_object(task)
		        slice_success("Task [#{task.uuid}] removed", :success_type => :removed)
			end
			
			def start_task
				@command = :start_task
		        task_uuid = get_uuid_from_prev_args
		        # get the task to update
		        task = get_object("task_with_uuid", :task, task_uuid)
		        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Task with UUID: [#{task_uuid}]" unless task && (task.class != Array || task.length > 0)	
		        # check status
		        raise ProjectRazor::Error::Slice::InvalidCommand, "Invalid Command start for [#{task.uuid}]" unless task.fsm[task.status][:start]
		        #get nodes and create policies
		        # binding.pry
				options               = {}
				options[:label]		  = task.label
				options[:model_uuid]  = task.scheme.model_uuid
				options[:broker_uuid] = (task.scheme.broker_uuid ? task.scheme.broker_uuid : "none")
				#TODO
				options[:template] = "linux_deploy"

				options[:maximum] = "0" if
				options[:enabled] = "true" 
		        task.scheme.nodes_uuid.each do |node_uuid|
			        # check the values that were passed in
			        policy = new_object_from_template_name(POLICY_PREFIX, options[:template])

			        # check for errors in inputs
			        raise ProjectRazor::Error::Slice::InvalidPolicyTemplate, "Policy Template is not valid [#{options[:template]}]" unless policy
			        setup_data
			        model = get_object("model_by_uuid", :model, options[:model_uuid])
			        raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Model UUID [#{options[:model_uuid]}]" unless model && (model.class != Array || model.length > 0)
			        raise ProjectRazor::Error::Slice::InvalidModel, "Invalid Model Type [#{model.template}] != [#{policy.template}]" unless policy.template == model.template
			        broker = get_object("broker_by_uuid", :broker, options[:broker_uuid])
			        raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Broker UUID [#{options[:broker_uuid]}]" unless (broker && (broker.class != Array || broker.length > 0)) || options[:broker_uuid] == "none"
					node = get_object("node_by_uuid", :node, node_uuid)
					raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Node UUID [#{node_uuid}]" unless (node && (node.class != Array || node.length > 0)) || options[:nodes_uuid] == "none"
			        # binding.pry
			        options[:tags] = ["hostname_#{node.attributes_hash['hostname']}"]
			        raise ProjectRazor::Error::Slice::MissingTags, "Must provide at least one tag [tags]" unless options[:tags].count > 0
			        # Flesh out the policy
			        policy.label         = options[:label]
			        policy.model         = model
			        policy.broker        = broker
			        policy.tags          = options[:tags]
			        policy.enabled       = options[:enabled]
			        policy.is_template   = false
			        policy.maximum_count = options[:maximum]
			        # Add policy
			        task.policies << policy.uuid
			        task.nodes    << node.uuid
			        policy_rules         = ProjectRazor::Policies.instance
			        policy_rules.add(policy) ? print_object_array([policy], "Policy created", :success_type => :created) :
			            raise(ProjectRazor::Error::Slice::CouldNotCreate, "Could not create Policy")
		        end
		        task.update_status(:start)
		        task.update_self
		        print_object_array([task], "Task started", :success_type => :started)
			end

			def retry_task
				@command = :retry_task
				task_uuid = get_uuid_from_prev_args
		        # get the task to retry
		        task = get_object("task_with_uuid", :task, task_uuid)
		        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Task with UUID: [#{task_uuid}]" unless task && (task.class != Array || task.length > 0)
		        # TODO check status
		        raise ProjectRazor::Error::Slice::InvalidCommand, "Invalid Command retry for [#{task.uuid}]" unless task.fsm[task.status][:retry]
		        # delete failed active_models
		        binding.pry
				task.active_models.each do |k,v|
					active_model = get_object("active_model_with_uuid", :active, k)
					@data.delete_object(active_model) unless active_model.model.current_state.to_s == :os_complete
				end
		        task.update_status(:retry)
		        task.update_self
		        print_object_array([task], "Task started", :success_type => :started)				
			end

			def abort_task
				@command = :abort_task
				task_uuid = get_uuid_from_prev_args
		        # get the task to abort
		        task = get_object("task_with_uuid", :task, task_uuid)
		        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Task with UUID: [#{task_uuid}]" unless task && (task.class != Array || task.length > 0)				
		        # TODO check status
		        raise ProjectRazor::Error::Slice::InvalidCommand, "Invalid Command abort for [#{task.uuid}]" unless task.fsm[task.status][:abort]
		        # delete all policies
				task.policies.each do |policy|
					# binding.pry
					policy = get_object("policy_with_uuid", :policy, policy)
					@data.delete_object(policy)
				end
				# delete all active_models
				task.active_models.each do |k,v|
					active_model = get_object("active_model_with_uuid", :active, k)
					@data.delete_object(active_model)
				end
				task.update_status(:abort)
		        task.update_self
		        print_object_array([task], "Task abort", :success_type => :completed)				
			end
			
			def ignore_task
				@command = :ignore_task
				task_uuid = get_uuid_from_prev_args
		        # get the task to ignore
		        task = get_object("task_with_uuid", :task, task_uuid)
		        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Task with UUID: [#{task_uuid}]" unless task && (task.class != Array || task.length > 0)				
				#TODO check status
		        raise ProjectRazor::Error::Slice::InvalidCommand, "Invalid Command ignore for [#{task.uuid}]" unless task.fsm[task.status][:ignore]
				# delete all policies
				task.policies.each  do |policy|
					policy = get_object("policy_with_uuid", :policy, policy)
					@data.delete_object(policy)
				end
				# delete failed active_models
				task.active_models.each do |k,v|
					active_model = get_object("active_model_with_uuid", :active, k)
					@data.delete_object(active_model) unless active_model.model.current_state.to_s == active_model.model.final_state.to_s
				end
				task.update_status(:ignore)
		        task.update_self
		        print_object_array([task], "Task started", :success_type => :completed)
		    end
		end
	end
end