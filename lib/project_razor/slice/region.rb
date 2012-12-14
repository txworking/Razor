
module ProjectRazor
	class Slice
		class Region < ProjectRazor::Slice
			
			def initialize(args)
				super(args)
		        @hidden          = false
		        @slice_name      = "Region"

		        # get the slice commands map for this slice (based on the set
		        # of commands that are typical for most slices)
		        @slice_commands = get_command_map("region_help",
		                                          "get_all_regions",
		                                          "get_region_by_uuid",
		                                          "add_region",
		                                          "update_region",
		                                          "remove_all_regions",
		                                          "remove_region_by_uuid")
		        # and add any additional commands specific to this slice
		        @slice_commands[:get].delete(/^(?!^(all|\-\-help|\-h|\{\}|\{.*\}|nil)$)\S+$/)
		        @slice_commands[:get][:else] = "get_region_by_uuid"

				
			end

			def region_help
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
		        puts get_region_help
			end

			def get_region_help
		        return ["Region Slice:".red,
		                "Used to view, create, update, and remove regions.".red,
		                "Region commands:".yellow,
		                "\trazor region [get] [all]                      " + "View all regions".yellow,
		                "\trazor region [get] (UUID)                     " + "View a specific region".yellow,
		                "\trazor region add (options...)                 " + "Create a new region".yellow,
		                "\trazor region update (UUID) (options...)       " + "Update an existing region".yellow,
		                "\trazor region remove (UUID)|all                " + "Remove existing region(s)".yellow,
		                "\trazor region --help|-h                        " + "Display this screen".yellow].join("\n")
				
			end

			def get_all_regions
		        @command = :get_all_regions
		        # if it's a web command and the last argument wasn't the string "default" or "get", then a
		        # filter expression was included as part of the web command
		        @command_array.unshift(@prev_args.pop) if @web_command && @prev_args.peek(0) != "default" && @prev_args.peek(0) != "get"
		        # Get all region instances and print/return
		        print_object_array get_object("regions", :region), "Regions", :style => :table
			end

			def get_region_by_uuid
		        @command = :get_region_by_uuid
		        # the UUID is the first element of the @command_array
		        region_uuid = @command_array.first
		        region = get_object("get_region_by_uuid", :region, region_uuid)
		        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Region with UUID: [#{region_uuid}]" unless region && (region.class != Array || region.length > 0)
		        print_object_array [region], "", :success_type => :generic
			end

			def add_region
		        @command = :add_region
		        includes_uuid = false
		        # load the appropriate option items for the subcommand we are handling
		        option_items = load_option_items(:command => :add)
		        # parse and validate the options that were passed in as part of this
		        # subcommand (this method will return a UUID value, if present, and the
		        # options map constructed from the @commmand_array)
		        tmp, options = parse_and_validate_options(option_items, "razor region add (options...)", :require_all)
		        includes_uuid = true if tmp && tmp != "add"
		        # check for usage errors (the boolean value at the end of this method
		        # call is used to indicate whether the choice of options from the
		        # option_items hash must be an exclusive choice)
		        check_option_usage(option_items, options, includes_uuid, false)
				#check unique
				region_tmp = return_objects_using_filter(:region, {"name" => options[:name]})
		        if !region_tmp.empty?
		        	return print_object_array(region_tmp, "", :success_type => :created)
		        end		        
		        # create a new region using the options that were passed into this subcommand,
		        # then persist the region object
		        region = ProjectRazor::Region.new({"@name" => options[:name]})
		        raise(ProjectRazor::Error::Slice::CouldNotCreate, "Could not create Region") unless region
		        setup_data
		        @data.persist_object(region)
		        print_object_array([region], "", :success_type => :created)
			end

			def update_region
				@command = :update_region
		        includes_uuid = false
		        # load the appropriate option items for the subcommand we are handling
		        option_items = load_option_items(:command => :update)
		        # parse and validate the options that were passed in as part of this
		        # subcommand (this method will return the options map constructed
		        # from the @commmand_array)
		        region_uuid, options = parse_and_validate_options(option_items, "razor region update (UUID) (options...)", :require_one)
		        includes_uuid = true if region_uuid
		        # check for usage errors (the boolean value at the end of this method
		        # call is used to indicate whether the choice of options from the
		        # option_items hash must be an exclusive choice)
		        check_option_usage(option_items, options, includes_uuid, false)
				#check unique
				region_tmp = return_objects_using_filter(:region, {"name" => options[:name]})
		        if !region_tmp.empty? && region_uuid != region_tmp[0].uuid
		        	raise ProjectRazor::Error::Slice::CouldNotUpdate, "Could not change to Region name [#{options[:name]}]"
		        end		        
		        # get the region to update
		        region = get_object("region_with_uuid", :region, region_uuid)
		        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Region with UUID: [#{region_uuid}]" unless region && (region.class != Array || region.length > 0)
		        region.name = options[:name] if options[:name]
		        raise ProjectRazor::Error::Slice::CouldNotUpdate, "Could not update Region [#{region.uuid}]" unless region.update_self
		        print_object_array [region], "", :success_type => :updated				
			end

			def remove_all_regions
		        @command = :remove_all_regions
		        raise ProjectRazor::Error::Slice::MethodNotAllowed, "Cannot remove all Regions via REST" if @web_command
				begin
					return_objects(:node).each do |node|
		        		node.region = nil
		        		setup_data
		        		node.update_self
		        	end		        						
				rescue Exception 
					raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove all Regions"					
				end
		        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove all Regions" unless @data.delete_all_objects(:region)
		        slice_success("All Regions removed", :success_type => :removed)
			end

			def remove_region_by_uuid
		        @command = :remove_region_by_uuid
		        # the UUID was the last "previous argument"
		        region_uuid = get_uuid_from_prev_args
		        region = get_object("region_with_uuid", :region, region_uuid)
		        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Region with UUID: [#{region_uuid}]" unless region && (region.class != Array || region.length > 0)
		        setup_data
				begin
					return_objects(:node).each do |node|
						if node.region && node.region[:uuid].equal(region_uuid)
							node.region = nil
			        		setup_data
			        		node.update_self								
						end
		        	end		        						
				rescue Exception 
					raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove Region [#{region.uuid}]"
				end
		        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove Region [#{region.uuid}]" unless @data.delete_object(region)
		        slice_success("Region [#{region.uuid}] removed", :success_type => :removed)
			end
		end
	end
end