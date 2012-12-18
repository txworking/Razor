module ProjectRazor
	class Slice
		class Task < ProjectRazor::Slice
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
				task.enabled       = false
				task.policies      = nil
				task.active_models = nil
				task.nodes         = nil
				task.status        =nil
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
		        task.label = options[:label] if options[:label]
				if options[:scheme_uuid]
          			scheme = get_object("scheme_by_uuid", :scheme, options[:scheme_uuid])
          			raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Scheme UUID [#{options[:scheme_uuid]}]" unless scheme && (scheme.class != Array || scheme.length > 0)
          		end
		        task.scheme = scheme if options[:scheme_uuid]
		        #TODO 
				task.enabled       = false
				task.policies      = nil
				task.active_models = nil
				task.nodes         = nil
				task.status 	   = nil
		        raise ProjectRazor::Error::Slice::CouldNotUpdate, "Could not update Task [#{task.uuid}]" unless task.update_self
		        print_object_array [task], "", :success_type => :updated				
			end

			def remove_all_tasks
		        @command = :remove_all_tasks
		        raise ProjectRazor::Error::Slice::MethodNotAllowed, "Cannot remove all Tasks via REST" if @web_command
		        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove all Tasks" unless @data.delete_all_objects(:task)
		        slice_success("All Tasks removed", :success_type => :removed)
			end

			def remove_task_by_uuid
		        @command = :remove_task_by_uuid
		        # the UUID was the last "previous argument"
		        task_uuid = get_uuid_from_prev_args
		        task = get_object("task_with_uuid", :task, task_uuid)
		        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Task with UUID: [#{task_uuid}]" unless task && (task.class != Array || task.length > 0)
		        setup_data
		        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove Task [#{task.uuid}]" unless @data.delete_object(task)
		        slice_success("Task [#{task.uuid}] removed", :success_type => :removed)
			end

		end
	end
end