require 'event_store'

db_config = Hash[
    :username => 'postgres',
    :password => 'Password1',
    host: 'ec2-54-221-80-232.compute-1.amazonaws.com',
    encoding: 'utf8',
    pool: 1000,
    adapter: :postgres,
    database: 'event_store_performance'
  ]

EventStore.connect ( db_config )

DEVICES = 1000
EVENTS_PER_DEVICE = 5_000
EVENT_TYPES = 1000

event_types = Array.new(EVENT_TYPES) { |i| "event_type_#{i}" }

puts "Creating #{DEVICES} Aggregates with #{EVENTS_PER_DEVICE} events each. There are #{EVENT_TYPES} types of events."

(1..DEVICES).each do |device_id|
  client = EventStore::Client.new(device_id, :device)
  records = []

  EVENTS_PER_DEVICE.times do
    records << EventStore::Event.new(device_id.to_s, DateTime.now, event_types.sample, 9999999999999.to_s(2))
  end

  puts "Appending #{EVENTS_PER_DEVICE} events for #{device_id} of #{DEVICES} Aggregates."
  start_time = Time.now
  client.append(records)
  end_time = Time.now
  total_time = end_time - start_time
  puts "Success! (Total Time: #{total_time} = #{(EVENTS_PER_DEVICE) / total_time} inserts per second)"
end



