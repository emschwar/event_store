require 'minitest_helper'

# run once setup
[1, 2].each do |device_id|
  [2, 3].each do |sequence_number|
    10.times do
      event = EventStore::Event.new :device_id => device_id, :sequence_number => sequence_number
      event.stub :validate, true do
        event.save
      end
    end
  end
end

describe EventStore::Client do
  before { @es_client = EventStore::Client }

  describe 'event streams' do
    it 'should be empty for devices without events' do
      stream = @es_client.new(100).event_stream
      assert stream.empty?
    end

    it 'should be for a single device' do
      stream = @es_client.new(1).event_stream
      assert stream.map(&:device_id).all?{ |device_id| device_id == '1' }, 'Fetched multiple device_ids in the event stream'
    end

    it 'should include all events for that device' do
      stream = @es_client.new(1).event_stream
      assert_equal 20, stream.count
    end
  end


  describe 'event streams from sequence' do
    subject { @es_client.new(1) }

    it 'should return only events from the specified sequence' do
      stream = subject.event_stream_from(2)
      assert stream.map(&:sequence_number).all?{ |sequence_number| sequence_number == 2 }, 'Fetched multiple sequence_ids in the event stream'
    end

    it 'by default it should return all events in the sequence' do
      stream = subject.event_stream_from(2)
      assert_equal 10, stream.count
    end

    it 'should respect the max, if specified' do
      stream = subject.event_stream_from(2, 5)
      assert_equal 5, stream.count
    end

    it 'should be empty for sequences that do not exist' do
      stream = subject.event_stream_from(43)
      assert stream.empty?
    end
  end

  describe '#peek' do
    subject { @es_client.new(1).peek }

    it 'should return one event' do
      assert_equal EventStore::Event, subject.class
    end

    it 'should return the last event in the event stream' do
      skip "what qualifies as last event needs clarification"
    end
  end

  describe '#append' do
    it 'should raise if the expected_sequence_number is before the last_sequence_number' do
      skip "needs clarification"
    end

    it 'create the events' do
      skip "needs clarification"
    end

    it 'yield to the black after event creation' do
      skip "needs clarification"
    end

    it 'is run in a transaction' do
      skip "put in two events, one valid one invalid, and assert that neither are persisted"
    end
  end

end
