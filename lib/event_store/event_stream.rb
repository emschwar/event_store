module EventStore
  class EventStream
    include Enumerable

    attr_reader :event_table

    def initialize aggregate
      @aggregate = aggregate
      @id = @aggregate.id
      @event_table_alias = "events"
      @event_table = "#{EventStore.schema}__#{EventStore.table_name}".to_sym
      @aliased_event_table = "#{event_table}___#{@event_table_alias}".to_sym
      @names_table = EventStore.fully_qualified_names_table
    end

    def append(raw_events)
      prepared_events = raw_events.map do |raw_event|
        event = prepare_event(raw_event)
        ensure_all_attributes_have_values!(event)
        event
      end

      event_table = EventStore.db.from(@event_table)
      prepared_events.each do |event|
        event_hash = event.dup.reject! { |k,v| k == :fully_qualified_name }

        begin
          id = event_table.insert(event_hash)
        rescue Sequel::NotNullConstraintViolation
          fully_qualified_names.insert(fully_qualified_name: event[:fully_qualified_name])
          id = event_table.insert(event_hash)
        end

        event[:id] = id
      end

      yield(prepared_events) if block_given?
    end

    def fully_qualified_names
      @fully_qualified_name_query ||= EventStore.db.from(@names_table)
    end

    def events
      @events_query ||= EventStore.db.from(@aliased_event_table)            \
                          .where(:aggregate_id => @id.to_s)                 \
                          .join(@names_table, id: :fully_qualified_name_id) \
                          .order("#{@event_table_alias}__id".to_sym)        \
                          .select_all(:events).select_append(:fully_qualified_name)
    end

    def events_from(event_id, max = nil)
      # note: this depends on the events table being aliased to "events" above.
      events.limit(max).where{events__id >= event_id.to_i }.all.map do |event|
        event[:serialized_event] = EventStore.unescape_bytea(event[:serialized_event])
        event
      end
    end

    def last_event_before(start_time, fully_qualified_names = [])
      timestampz = start_time.strftime("%Y-%m-%d %H:%M:%S%z")

      rows = fully_qualified_names.inject([]) { |memo, name|
        memo + events.where(fully_qualified_name: name).where{ occurred_at < timestampz }
                 .reverse_order(:occurred_at).limit(1).all
      }.sort_by { |r| r[:occurred_at] }

      rows.map {|r| r[:serialized_event] = EventStore.unescape_bytea(r[:serialized_event]); r}
    end

    def event_stream_between(start_time, end_time, fully_qualified_names = [])
      query = events.where(occurred_at: start_time..end_time)
      query = query.where(fully_qualified_name: fully_qualified_names) if fully_qualified_names && fully_qualified_names.any?
      query.all.map {|e| e[:serialized_event] = EventStore.unescape_bytea(e[:serialized_event]); e}
    end

    def last
      to_a.last
    end

    def empty?
      events.empty?
    end

    def each
      events.all.each do |e|
        e[:serialized_event] = EventStore.unescape_bytea(e[:serialized_event])
        yield e
      end
    end

    def delete_events!
      EventStore.db.from(@event_table).where(:aggregate_id => @id.to_s).delete
    end

  private

    def prepare_event(raw_event)
      raise ArgumentError.new("Cannot Append a Nil Event") unless raw_event
      { :aggregate_id            => raw_event.aggregate_id,
        :occurred_at             => Time.parse(raw_event.occurred_at.to_s).utc, #to_s truncates microseconds, which brake Time equality
        :serialized_event        => EventStore.escape_bytea(raw_event.serialized_event),
        :fully_qualified_name_id => EventStore.db.from(@names_table).where(fully_qualified_name: raw_event.fully_qualified_name).select(:id),
        :fully_qualified_name    => raw_event.fully_qualified_name,
        :sub_key                 => raw_event.sub_key
      }
    end

    def ensure_all_attributes_have_values!(event_hash)
      [:aggregate_id, :fully_qualified_name, :occurred_at, :serialized_event].each do |attribute_name|
        if event_hash[attribute_name].to_s.strip.empty?
          raise AttributeMissingError, "value required for #{attribute_name}"
        end
      end
    end
  end
end
