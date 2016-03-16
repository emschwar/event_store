require "spec_helper"
require "securerandom"

AGGREGATE_ID_ONE = SecureRandom.uuid
AGGREGATE_ID_TWO = SecureRandom.uuid

module EventStore
  describe "Snapshots" do
    context "when there are no events" do
      let(:client)    { EventStore::Client.new(AGGREGATE_ID_ONE) }

      it "should build an empty snapshot for a new client" do
        expect(client.snapshot.any?).to eq(false)
        expect(client.event_id).to eq(-1)
        expect(EventStore.redis.hget(client.snapshot_event_id_table, :current_event_id)).to eq(nil)
      end

      it "a client should rebuild a snapshot" do
        expect_any_instance_of(EventStore::Aggregate).to receive(:delete_snapshot!)
        expect_any_instance_of(EventStore::Aggregate).to receive(:rebuild_snapshot!)
        client.rebuild_snapshot!
      end
    end

    context "with events in the stream" do
      let(:client)    { EventStore::Client.new(AGGREGATE_ID_TWO) }

      before do
        expect(client.snapshot.count).to eq(0)
        client.append events_for(AGGREGATE_ID_TWO)
      end

      describe "#count" do
        it "delegates to the snapshot hash" do
          expect(client.snapshot.count).to eq(8)
        end
      end

      describe "#update_fqns!" do
        let(:original_events)  { client.snapshot.to_a }

        it "replaces fully qualified names in the snapshot with the value of a block" do
          client.snapshot.update_fqns! { |fqn|
            fqn =~ /^(e[0-9])/ ? fqn.upcase : fqn
          }

          expected_snapshot_events = original_events.map { |serialized_event| serialized_event.fully_qualified_name.upcase }
          expect(client.snapshot.map(&:fully_qualified_name).to_set).to eq(expected_snapshot_events.to_set)
        end

        it "does not affect the current event id" do
          old_event_id = client.snapshot.event_id

          client.snapshot.update_fqns! { |fqn| fqn.upcase }

          new_event_id = client.snapshot.event_id

          expect(new_event_id).to eq(old_event_id)
        end

        it "doesn't affect the fully qualified name when the block returns nil" do
          old_fqns = original_events.map(&:fully_qualified_name)
          client.snapshot.update_fqns! { |_fqn| nil }

          expect(client.snapshot.map(&:fully_qualified_name).to_set).to eq(old_fqns.to_set)
        end
      end

      it "rebuilds a snapshot after it is deleted" do
        snapshot = client.snapshot
        client.delete_snapshot!
        client.rebuild_snapshot!
        expect(client.snapshot).to eq(snapshot)
      end

      it "automatically rebuilds the snapshot if events exist, but the snapshot is empty" do
        snapshot = client.snapshot
        client.delete_snapshot!
        expect(client.snapshot).to eq(snapshot)
      end

      it "finds the most recent records for each type" do
        expected_snapshot_events = %w{e3 e1 e2 e5 e4 e7 e8 e7} #sorted by version no
        expected_snapshot = serialized_events(expected_snapshot_events)
        actual_snapshot = client.snapshot

        expect(client.event_stream.count).to eq(15)
        expect(actual_snapshot.map(&:fully_qualified_name)).to eq(expected_snapshot_events)
        expect(actual_snapshot.count).to eq(8)
        expect(actual_snapshot.map(&:serialized_event)).to eq(expected_snapshot.map(&:serialized_event))
      end

      it "increments the version number of the snapshot when an event is appended" do
        expect(client.snapshot.event_id).to eq(client.raw_event_stream.last[:id])
      end
    end

    def events_for(device_id)
      events = %w{ e1 e2 e3 e1 e2 e4 e5 e2 e5 e4 }.map {|fqn| event_hash(device_id, fqn, EventStore::NO_SUB_KEY) }
      events += %w{ e7 e7 e8 }.map {|fqn| event_hash(device_id, fqn, "zone1") }
      events += %w{ e7 e7 }.map {|fqn| event_hash(device_id, fqn, "zone2") }
    end

    def event_hash(device_id, fqn, zone_id)
      EventStore::Event.new(device_id,
                            Time.now.utc,
                            fqn,
                            zone_id,
                            serialized_binary_event_data
                            )
    end

    def serialized_events(events)
      events.map {|fqn| EventStore::SerializedEvent.new(fqn, serialized_binary_event_data, 1 ) }
    end

    def serialized_binary_event_data
      @event_data ||= File.open(File.expand_path("../serialized_binary_event_data.txt", __FILE__), "rb") {|f| f.read}
      @event_data
    end

  end
end
