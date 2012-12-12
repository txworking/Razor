module	ProjectRazor

	class Slice
		class Tagname < ProjectRazor::Slice
			def initialize(args)
				super(args)
		        @hidden          = false
		        @slice_name      = "Tagname"

		        # get the slice commands map for this slice (based on the set
		        # of commands that are typical for most slices)
		        @slice_commands = get_command_map("tag_help",
		                                          "get_all_tags",
		                                          "get_tag_by_uuid",
		                                          "add_tag",
		                                          "update_tag",
		                                          "remove_all_tags",
		                                          "remove_tag_by_uuid")
		        # and add any additional commands specific to this slice
		        @slice_commands[:get].delete(/^(?!^(all|\-\-help|\-h|\{\}|\{.*\}|nil)$)\S+$/)
		        @slice_commands[:get][:else] = "get_tag_by_uuid"

				
			end

			def tag_help
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
		        puts get_tag_help
			end

			def get_tag_help
		        return ["Tagname Slice:".red,
		                "Used to view, create, update, and remove tags.".red,
		                "Tagname commands:".yellow,
		                "\trazor tag [get] [all]                      " + "View all tags".yellow,
		                "\trazor tag [get] (UUID)                     " + "View a specific tag".yellow,
		                "\trazor tag add (options...)                 " + "Create a new tag".yellow,
		                "\trazor tag update (UUID) (options...)       " + "Update an existing tag".yellow,
		                "\trazor tag remove (UUID)|all                " + "Remove existing tag(s)".yellow,
		                "\trazor tag --help|-h                        " + "Display this screen".yellow].join("\n")
				
			end

			def get_all_tags
		        @command = :get_all_tags
		        # if it's a web command and the last argument wasn't the string "default" or "get", then a
		        # filter expression was included as part of the web command
		        @command_array.unshift(@prev_args.pop) if @web_command && @prev_args.peek(0) != "default" && @prev_args.peek(0) != "get"
		        # Get all tag instances and print/return
		        print_object_array get_object("tags", :tag_name), "Tags", :style => :table
			end

			def get_tag_by_uuid
		        @command = :get_tag_by_uuid
		        # the UUID is the first element of the @command_array
		        tag_uuid = @command_array.first
		        tag = get_object("get_tag_by_uuid", :tag_name, tag_uuid)
		        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Tagname with UUID: [#{tag_uuid}]" unless tag && (tag.class != Array || tag.length > 0)
		        print_object_array [tag], "", :success_type => :generic
			end

			def add_tag
		        @command = :add_tag
		        includes_uuid = false
		        # load the appropriate option items for the subcommand we are handling
		        option_items = load_option_items(:command => :add)
		        # parse and validate the options that were passed in as part of this
		        # subcommand (this method will return a UUID value, if present, and the
		        # options map constructed from the @commmand_array)
		        tmp, options = parse_and_validate_options(option_items, "razor tag add (options...)", :require_all)
		        includes_uuid = true if tmp && tmp != "add"
		        # check for usage errors (the boolean value at the end of this method
		        # call is used to indicate whether the choice of options from the
		        # option_items hash must be an exclusive choice)
		        check_option_usage(option_items, options, includes_uuid, false)
		        tag_tmp = return_objects_using_filter(:tag_name, {"name" => options[:name]})
		        if !tag_tmp.empty?
		        	return print_object_array(tag_tmp, "", :success_type => :created)	
		        end
		        # create a new tag using the options that were passed into this subcommand,
		        # then persist the tag object
		        tag = ProjectRazor::Tagname.new({"@name" => options[:name]})
		        raise(ProjectRazor::Error::Slice::CouldNotCreate, "Could not create Tagname") unless tag
		        setup_data
		        @data.persist_object(tag)
		        print_object_array([tag], "", :success_type => :created)
			end

			def update_tag
				@command = :update_tag
		        includes_uuid = false
		        # load the appropriate option items for the subcommand we are handling
		        option_items = load_option_items(:command => :update)
		        # parse and validate the options that were passed in as part of this
		        # subcommand (this method will return the options map constructed
		        # from the @commmand_array)
		        tag_uuid, options = parse_and_validate_options(option_items, "razor tag update (UUID) (options...)", :require_one)
		        includes_uuid = true if tag_uuid
		        # check for usage errors (the boolean value at the end of this method
		        # call is used to indicate whether the choice of options from the
		        # option_items hash must be an exclusive choice)
		        check_option_usage(option_items, options, includes_uuid, false)

		        # get the tag to update
		        tag = get_object("tag_with_uuid", :tag_name, tag_uuid)
		        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Tagname with UUID: [#{tag_uuid}]" unless tag && (tag.class != Array || tag.length > 0)

		        #check unique
				tag_tmp = return_objects_using_filter(:tag_name, {"name" => options[:name]})
		        if !tag_tmp.empty?
		        	raise ProjectRazor::Error::Slice::CouldNotUpdate, "Could not change to Tagname [#{options[:name]}]"
		        end

		        tag.name = options[:name] if options[:name]
		        raise ProjectRazor::Error::Slice::CouldNotUpdate, "Could not update Tagname [#{tag.uuid}]" unless tag.update_self
		        print_object_array [tag], "", :success_type => :updated				
			end

			def remove_all_tags
		        @command = :remove_all_tags
		        raise ProjectRazor::Error::Slice::MethodNotAllowed, "Cannot remove all Tags via REST" if @web_command
		        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove all Tags" unless @data.delete_all_objects(:tag_name)
		        slice_success("All Tags removed", :success_type => :removed)
			end

			def remove_tag_by_uuid
		        @command = :remove_tag_by_uuid
		        # the UUID was the last "previous argument"
		        tag_uuid = get_uuid_from_prev_args
		        tag = get_object("tag_with_uuid", :tag_name, tag_uuid)
		        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Tagname with UUID: [#{tag_uuid}]" unless tag && (tag.class != Array || tag.length > 0)
		        setup_data
		        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove Tagname [#{tag.uuid}]" unless @data.delete_object(tag)
		        slice_success("Tagname [#{tag.uuid}] removed", :success_type => :removed)
			end

		end
	end
end



