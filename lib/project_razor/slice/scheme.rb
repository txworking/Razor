module ProjectRazor
	class Slice
		class Scheme < ProjectRazor::Slice
			def initialize(args)
				super(args)
		        @hidden          = false
		        @slice_name      = "Scheme"

		        # get the slice commands map for this slice (based on the set
		        # of commands that are typical for most slices)
		        @slice_commands = get_command_map("scheme_help",
		                                          "get_all_schemes",
		                                          "get_scheme_by_uuid",
		                                          "add_scheme",
		                                          "update_scheme",
		                                          "remove_all_schemes",
		                                          "remove_scheme_by_uuid")
		        # and add any additional commands specific to this slice
		        @slice_commands[:get].delete(/^(?!^(all|\-\-help|\-h|\{\}|\{.*\}|nil)$)\S+$/)
		        @slice_commands[:get][:else] = "get_scheme_by_uuid"

				
			end

			def scheme_help
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
		        puts get_scheme_help
			end

			def get_scheme_help
		        return ["Scheme Slice:".red,
		                "Used to view, create, update, and remove schemes.".red,
		                "Scheme commands:".yellow,
		                "\trazor scheme [get] [all]                      " + "View all schemes".yellow,
		                "\trazor scheme [get] (UUID)                     " + "View a specific scheme".yellow,
		                "\trazor scheme add (options...)                 " + "Create a new scheme".yellow,
		                "\trazor scheme update (UUID) (options...)       " + "Update an existing scheme".yellow,
		                "\trazor scheme remove (UUID)|all                " + "Remove existing scheme(s)".yellow,
		                "\trazor scheme --help|-h                        " + "Display this screen".yellow].join("\n")
				
			end

			def get_all_schemes
		        @command = :get_all_schemes
		        # if it's a web command and the last argument wasn't the string "default" or "get", then a
		        # filter expression was included as part of the web command
		        @command_array.unshift(@prev_args.pop) if @web_command && @prev_args.peek(0) != "default" && @prev_args.peek(0) != "get"
		        # Get all scheme instances and print/return
		        print_object_array get_object("schemes", :scheme), "Schemes", :style => :table
			end

			def get_scheme_by_uuid
		        @command = :get_scheme_by_uuid
		        # the UUID is the first element of the @command_array
		        scheme_uuid = @command_array.first
		        scheme = get_object("get_scheme_by_uuid", :scheme, scheme_uuid)
		        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Scheme with UUID: [#{scheme_uuid}]" unless scheme && (scheme.class != Array || scheme.length > 0)
		        print_object_array [scheme], "", :success_type => :generic
			end

			def add_scheme
		        @command = :add_scheme
		        includes_uuid = false
		        # load the appropriate option items for the subcommand we are handling
		        option_items = load_option_items(:command => :add)
		        # parse and validate the options that were passed in as part of this
		        # subcommand (this method will return a UUID value, if present, and the
		        # options map constructed from the @commmand_array)
		        tmp, options = parse_and_validate_options(option_items, "razor scheme add (options...)", :require_all)
		        includes_uuid = true if tmp && tmp != "add"
		        # check for usage errors (the boolean value at the end of this method
		        # call is used to indicate whether the choice of options from the
		        # option_items hash must be an exclusive choice)
		        check_option_usage(option_items, options, includes_uuid, false)
				#check unique
				scheme_tmp = return_objects_using_filter(:scheme, {"label" => options[:label]})
		        if !scheme_tmp.empty?
		        	raise(ProjectRazor::Error::Slice::CouldNotCreate, "Could not create Scheme") 
		        end		        
		        # check for errors input
		        options[:broker_uuid] = "none" if !options[:broker_uuid]
				setup_data
				model = get_object("model_by_uuid", :model, options[:model_uuid])
        		raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Model UUID [#{options[:model_uuid]}]" unless model && (model.class != Array || model.length > 0)				
  				
  				broker = get_object("broker_by_uuid", :broker, options[:broker_uuid])
        		raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Broker UUID [#{options[:broker_uuid]}]" unless (broker && (broker.class != Array || broker.length > 0)) || options[:broker_uuid] == "none"

				options[:nodes_uuid]  = options[:nodes_uuid].split(",") if options[:nodes_uuid].is_a? String
				options[:nodes_uuid].each do |node_uuid|
					node = get_object("node_by_uuid", :node, node_uuid)
					raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Node UUID [#{node_uuid}]" unless (node && (node.class != Array || node.length > 0)) || options[:nodes_uuid] == "none"					
				end

		        # create a new scheme using the options that were passed into this subcommand,
		        # then persist the scheme object
		        scheme = ProjectRazor::Scheme.new({"@label" => options[:label]})
		        raise(ProjectRazor::Error::Slice::CouldNotCreate, "Could not create Scheme") unless scheme
				scheme.model_uuid  = options[:model_uuid]
				scheme.broker_uuid = options[:broker_uuid]
				scheme.nodes_uuid  = options[:nodes_uuid]
		        setup_data
		        @data.persist_object(scheme)
		        print_object_array([scheme], "", :success_type => :created)
			end

			def update_scheme
				@command = :update_scheme
		        includes_uuid = false
		        # load the appropriate option items for the subcommand we are handling
		        option_items = load_option_items(:command => :update)
		        # parse and validate the options that were passed in as part of this
		        # subcommand (this method will return the options map constructed
		        # from the @commmand_array)
		        scheme_uuid, options = parse_and_validate_options(option_items, "razor scheme update (UUID) (options...)", :require_one)
		        includes_uuid = true if scheme_uuid
		        # check for usage errors (the boolean value at the end of this method
		        # call is used to indicate whether the choice of options from the
		        # option_items hash must be an exclusive choice)
		        check_option_usage(option_items, options, includes_uuid, false)
				#check unique
				scheme_tmp = return_objects_using_filter(:scheme, {"label" => options[:label]})
		        if !scheme_tmp.empty? && scheme_uuid != scheme_tmp[0].uuid
		        	raise ProjectRazor::Error::Slice::CouldNotUpdate, "Could not change to Scheme name [#{options[:name]}]"
		        end		        
		        # get the scheme to update
		        scheme = get_object("scheme_with_uuid", :scheme, scheme_uuid)
		        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Scheme with UUID: [#{scheme_uuid}]" unless scheme && (scheme.class != Array || scheme.length > 0)
		        
		        if options[:model_uuid] 
					model = get_object("model_by_uuid", :model, options[:model_uuid])
	        		raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Model UUID [#{options[:model_uuid]}]" unless model && (model.class != Array || model.length > 0)	
	      		end

	  			if options[:broker_uuid]
	  				broker = get_object("broker_by_uuid", :broker, options[:broker_uuid])
	        		raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Broker UUID [#{options[:broker_uuid]}]" unless (broker && (broker.class != Array || broker.length > 0)) || options[:broker_uuid] == "none"
				end

				if options[:nodes_uuid]
					options[:nodes_uuid]  = options[:nodes_uuid].split(",") if options[:nodes_uuid].is_a? String
					options[:nodes_uuid].each do |node_uuid|
						node = get_object("node_by_uuid", :node, node_uuid)
						raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Node UUID [#{node_uuid}]" unless (node && (node.class != Array || node.length > 0)) || options[:nodes_uuid] == "none"
					end
				end
				
				scheme.label       = options[:label] 		if options[:label]
				scheme.model_uuid  = options[:model_uuid] 	if options[:model_uuid]
				scheme.broker_uuid = options[:broker_uuid] 	if options[:broker_uuid]
				scheme.nodes_uuid  = options[:nodes_uuid] 	if options[:nodes_uuid]
				raise ProjectRazor::Error::Slice::CouldNotUpdate, "Could not update Scheme [#{scheme.uuid}]" unless scheme.update_self
		        print_object_array [scheme], "", :success_type => :updated				
			end

			def remove_all_schemes
		        @command = :remove_all_schemes
		        raise ProjectRazor::Error::Slice::MethodNotAllowed, "Cannot remove all Schemes via REST" if @web_command
		        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove all Schemes" unless @data.delete_all_objects(:scheme)
		        slice_success("All Schemes removed", :success_type => :removed)
			end

			def remove_scheme_by_uuid
		        @command = :remove_scheme_by_uuid
		        # the UUID was the last "previous argument"
		        scheme_uuid = get_uuid_from_prev_args
		        scheme = get_object("scheme_with_uuid", :scheme, scheme_uuid)
		        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Scheme with UUID: [#{scheme_uuid}]" unless scheme && (scheme.class != Array || scheme.length > 0)
		        setup_data
		        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove Scheme [#{scheme.uuid}]" unless @data.delete_object(scheme)
		        slice_success("Scheme [#{scheme.uuid}] removed", :success_type => :removed)
			end
		end
	end
end


