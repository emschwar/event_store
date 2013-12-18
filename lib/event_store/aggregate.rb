module EventStore
  class Aggregate

    def initialize id, type
      @id = id
      @type = type
    end

    def events
      @events ||= event_class.for_aggregate(@id)
    end

    def event_class
      if EventStore.const_defined?(event_class_name)
        EventStore.const_get(event_class_name)
      else
        event_table_name = "#{@type}_events"
        typed_event_class = Class.new(EventStore::Event) do
          set_dataset from(event_table_name)
        end
        EventStore.const_set(event_class_name, typed_event_class)
      end
    end

    def current_state
      event_types.map { |et| events.of_type(et).last }
    end

    private

    def event_types
      events.select(:fully_qualified_name).group(:fully_qualified_name).map(&:fully_qualified_name)
    end

    def event_class_name
      @event_class_name ||= "#{@type.to_s.capitalize}Event"
    end

  end
end