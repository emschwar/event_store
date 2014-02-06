require 'event_store'
Sequel.migration do
  up do
    schema = 'events'
    run %Q< CREATE SCHEMA #{schema};

          #{EventStore.event_table_creation_ddl(:vertica).gsub(';', '')}
          PARTITION BY EXTRACT(year FROM occurred_at)*100 + EXTRACT(month FROM occurred_at);

          CREATE PROJECTION events.device_events_super_projecion /*+createtype(D)*/
          (
           id ENCODING COMMONDELTA_COMP,
           version ENCODING COMMONDELTA_COMP,
           aggregate_id ENCODING RLE,
           fully_qualified_name ENCODING AUTO,
           occurred_at ENCODING BLOCKDICT_COMP,
           serialized_event ENCODING AUTO
          )
          AS
           SELECT id,
                  version,
                  aggregate_id,
                  fully_qualified_name,
                  occurred_at,
                  serialized_event
           FROM events.device_events
           ORDER BY aggregate_id,
                    version
          SEGMENTED BY HASH(aggregate_id) ALL NODES;

          CREATE PROJECTION events.device_events_runtime_history /*+createtype(D)*/
          (
           version ENCODING DELTAVAL,
           aggregate_id ENCODING RLE,
           fully_qualified_name ENCODING RLE,
           occurred_at ENCODING RLE,
           serialized_event ENCODING AUTO
          )
          AS
           SELECT version,
                  aggregate_id,
                  fully_qualified_name,
                  occurred_at,
                  serialized_event
           FROM events.device_events
           ORDER BY aggregate_id,
                    occurred_at,
                    fully_qualified_name
           SEGMENTED BY HASH(aggregate_id) ALL NODES;>
  end

  down do
    run 'DROP SCHEMA #{schema} CASCADE;'
  end
end
