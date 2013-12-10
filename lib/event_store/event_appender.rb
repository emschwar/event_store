module EventStore
  class EventAppender

    def initialize aggregate, expected_version
      @aggregate = aggregate
      @expected_version = expected_version
    end

    def append raw_events
      @aggregate.event_class.db.transaction do
        prepared_events = raw_events.map do |raw_event|
          event = prepare_event(raw_event)
          raise concurrency_error if has_concurrency_issue?(event)
          event
        end

        # All concurrency issues need to be checked before persisting any of the events
        # Otherwise, the newly appended events may raise erroneous concurrency errors
        prepared_events.each(&:save)
      end
    end

    private

    def concurrency_issue_possible?
      @potential_concurrency_issue ||= @expected_version < @aggregate.last_event.version
    end

    def has_concurrency_issue? event
      if concurrency_issue_possible?
        last_event_of_type = @aggregate.last_event_of_type(event.fully_qualified_name)
        last_event_of_type && @expected_version < last_event_of_type.version
      else
        false
      end
    end

    def prepare_event raw_event
      @aggregate.event_class.new do |e|
        e.aggregate_id         = raw_event.header.aggregate_id
        e.occurred_at          = raw_event.header.occurred_at
        e.data                 = raw_event.to_s
        e.fully_qualified_name = raw_event.fully_qualified_name
      end
    end

    def concurrency_error
      ConcurrencyError.new("Expected version #{@expected_version} does not occur after last version")
    end

  end
end