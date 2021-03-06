require 'forwardable'

module EventStore
  class Aggregate
    extend Forwardable

    attr_reader :id, :type, :event_table

    def_delegators :@snapshot,
      :last_event,
      :snapshot,
      :rebuild_snapshot!,
      :delete_snapshot!,
      :version,
      :version_for,
      :snapshot_version_table

    def_delegators :@event_stream,
      :events,
      :events_from,
      :event_stream,
      :event_stream_between,
      :event_table,
      :delete_events!

    def snapshot_exists?
      @snapshot.exists?
    end

    def self.count
      EventStore.db.from( EventStore.fully_qualified_table).distinct(:aggregate_id).count
    end

    def self.ids(offset, limit)
      EventStore.db.from( EventStore.fully_qualified_table).distinct(:aggregate_id).select(:aggregate_id).order(:aggregate_id).limit(limit, offset).all.map{|item| item[:aggregate_id]}
    end

    def initialize(id, type = EventStore.table_name)
      @id = id
      @type = type

      @snapshot     = Snapshot.new(self)
      @event_stream = EventStream.new(self)
    end

    def append(events)
      @event_stream.append(events) do |prepared_events|
        @snapshot.store_snapshot(prepared_events)
      end
    end

  end
end
