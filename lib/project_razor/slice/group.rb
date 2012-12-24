
module ProjectRazor
	class Slice
		class Group < ProjectRazor::Slice
			
			def initialize(args)
				super(args)
		        @hidden          = false
		        @slice_name      = "Group"

		        # get the slice commands map for this slice (based on the set
		        # of commands that are typical for most slices)
		        @slice_commands = get_command_map("group_help",
		                                          "get_all_groups",
		                                          "get_group_by_uuid",
		                                          "add_group",
		                                          "update_group",
		                                          "remove_all_groups",
		                                          "remove_group_by_uuid")
		        # and add any additional commands specific to this slice
		        @slice_commands[:get].delete(/^(?!^(all|\-\-help|\-h|\{\}|\{.*\}|nil)$)\S+$/)
		        @slice_commands[:get][:else] = "get_group_by_uuid"

				
			end

			def group_help
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
		        puts get_group_help
			end

			def get_group_help
		        return ["Group Slice:".red,
		                "Used to view, create, update, and remove groups.".red,
		                "Group commands:".yellow,
		                "\trazor group [get] [all]                      " + "View all groups".yellow,
		                "\trazor group [get] (UUID)                     " + "View a specific group".yellow,
		                "\trazor group add (options...)                 " + "Create a new group".yellow,
		                "\trazor group update (UUID) (options...)       " + "Update an existing group".yellow,
		                "\trazor group remove (UUID)|all                " + "Remove existing group(s)".yellow,
		                "\trazor group --help|-h                        " + "Display this screen".yellow].join("\n")
				
			end

			def get_all_groups
		        @command = :get_all_groups
		        # if it's a web command and the last argument wasn't the string "default" or "get", then a
		        # filter expression was included as part of the web command
		        @command_array.unshift(@prev_args.pop) if @web_command && @prev_args.peek(0) != "default" && @prev_args.peek(0) != "get"
		        # Get all group instances and print/return
		        print_object_array get_object("groups", :group), "Groups", :style => :table
			end

			def get_group_by_uuid
		        @command = :get_group_by_uuid
		        # the UUID is the first element of the @command_array
		        group_uuid = @command_array.first
		        group = get_object("get_group_by_uuid", :group, group_uuid)
		        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Group with UUID: [#{group_uuid}]" unless group && (group.class != Array || group.length > 0)
		        print_object_array [group], "", :success_type => :generic
			end

			def add_group
		        @command = :add_group
		        includes_uuid = false
		        # load the appropriate option items for the subcommand we are handling
		        option_items = load_option_items(:command => :add)
		        # parse and validate the options that were passed in as part of this
		        # subcommand (this method will return a UUID value, if present, and the
		        # options map constructed from the @commmand_array)
		        tmp, options = parse_and_validate_options(option_items, "razor group add (options...)", :require_all)
		        includes_uuid = true if tmp && tmp != "add"
		        # check for usage errors (the boolean value at the end of this method
		        # call is used to indicate whether the choice of options from the
		        # option_items hash must be an exclusive choice)
		        check_option_usage(option_items, options, includes_uuid, false)
				#check unique
				group_tmp = return_objects_using_filter(:group, {"name" => options[:name]})
		        if !group_tmp.empty?
		        	return print_object_array(group_tmp, "", :success_type => :created)
		        end		        
		        # create a new group using the options that were passed into this subcommand,
		        # then persist the group object
		        group = ProjectRazor::Group.new({"@name" => options[:name]})
		        raise(ProjectRazor::Error::Slice::CouldNotCreate, "Could not create Group") unless group
		        setup_data
		        @data.persist_object(group)
		        print_object_array([group], "", :success_type => :created)
			end

			def update_group
				@command = :update_group
		        includes_uuid = false
		        # load the appropriate option items for the subcommand we are handling
		        option_items = load_option_items(:command => :update)
		        # parse and validate the options that were passed in as part of this
		        # subcommand (this method will return the options map constructed
		        # from the @commmand_array)
		        group_uuid, options = parse_and_validate_options(option_items, "razor group update (UUID) (options...)", :require_one)
		        includes_uuid = true if group_uuid
		        # check for usage errors (the boolean value at the end of this method
		        # call is used to indicate whether the choice of options from the
		        # option_items hash must be an exclusive choice)
		        check_option_usage(option_items, options, includes_uuid, false)
				#check unique
				group_tmp = return_objects_using_filter(:group, {"name" => options[:name]})
		        if !group_tmp.empty? && group_uuid != group_tmp[0].uuid
		        	raise ProjectRazor::Error::Slice::CouldNotUpdate, "Could not change to Group name [#{options[:name]}]"
		        end		        
		        # get the group to update
		        group = get_object("group_with_uuid", :group, group_uuid)
		        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Group with UUID: [#{group_uuid}]" unless group && (group.class != Array || group.length > 0)
		        group.name = options[:name] if options[:name]
		        raise ProjectRazor::Error::Slice::CouldNotUpdate, "Could not update Group [#{group.uuid}]" unless group.update_self
		        print_object_array [group], "", :success_type => :updated				
			end

			def remove_all_groups
		        @command = :remove_all_groups
		        raise ProjectRazor::Error::Slice::MethodNotAllowed, "Cannot remove all Groups via REST" if @web_command
				begin
					return_objects(:node).each do |node|
		        		node.group = nil
		        		setup_data
		        		node.update_self
		        	end		        						
				rescue Exception 
					raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove all Groups"					
				end
		        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove all Groups" unless @data.delete_all_objects(:group)
		        slice_success("All Groups removed", :success_type => :removed)
			end

			def remove_group_by_uuid
		        @command = :remove_group_by_uuid
		        # the UUID was the last "previous argument"
		        group_uuid = get_uuid_from_prev_args
		        group = get_object("group_with_uuid", :group, group_uuid)
		        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Group with UUID: [#{group_uuid}]" unless group && (group.class != Array || group.length > 0)
		        setup_data
				begin
					return_objects(:node).each do |node|
						if node.group && node.group[:uuid].equal(group_uuid)
							node.group = nil
			        		setup_data
			        		node.update_self								
						end
		        	end		        						
				rescue Exception 
					raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove Group [#{group.uuid}]"
				end
		        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove Group [#{group.uuid}]" unless @data.delete_object(group)
		        slice_success("Group [#{group.uuid}] removed", :success_type => :removed)
			end
		end
	end
end