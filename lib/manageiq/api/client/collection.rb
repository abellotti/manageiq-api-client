module ManageIQ
  module API
    class Client
      class Collection
        include CollectionActionMixin
        include Enumerable
        include QueryableMixin

        CUSTOM_INSPECT_EXCLUSIONS = [:@client].freeze
        include CustomInspectMixin

        attr_reader :client

        attr_reader :name
        attr_reader :href
        attr_reader :description
        attr_reader :actions

        def initialize(client, collection_spec)
          raise "Cannot instantiate a Collection directly" if instance_of?(Collection)
          @client = client
          @name, @href, @description = collection_spec.values_at("name", "href", "description")
          clear_actions
        end

        def each(&block)
          all.each(&block)
        end

        def self.subclass(name)
          name = name.camelize

          if const_defined?(name, false)
            const_get(name, false)
          else
            const_set(name, Class.new(self))
          end
        end

        def get(api_options = {})
          api_options[:expand] = (String(api_options[:expand]).split(",") | %w(resources)).join(",")
          api_options[:filter] = Array(api_options[:filter]) if api_options[:filter].is_a?(String)

          klass = ManageIQ::API::Client::Resource.subclass(name)
          if options.configuration["options"].include?("hide_collection") && api_options[:identifier]
            Array(klass.new(self, client.get("#{name}/#{api_options[:identifier]}", api_options)))
          else
            result_hash = client.get(name, api_options)
            fetch_actions(result_hash)
            Array(result_hash["resources"]).collect do |resource_hash|
              klass.new(self, resource_hash)
            end.tap { |r| puts "TAPPING: #{r}" }
          end
        end

        def options
          @collection_options ||= CollectionOptions.new(client.options(name))
        end

        def resource_identifier
          options.configuration["resource_identifier"] || "id"
        end

        private

        def method_missing(sym, *args, &block)
          get unless actions_present?
          if action_defined?(sym)
            exec_action(sym, *args, &block)
          else
            super
          end
        end

        def respond_to_missing?(sym, *_)
          get unless actions_present?
          action_defined?(sym) || super
        end
      end
    end
  end
end
