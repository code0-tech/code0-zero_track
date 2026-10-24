# frozen_string_literal: true

class CreatePartitioningViews < Code0::ZeroTrack::Database::Migration[1.1]
  def up
    dynamic_schema = Rails.application.config.zero_track.db_partitioning.dynamic_partition_schema

    execute <<~SQL.squish
      CREATE OR REPLACE VIEW postgres_partitioned_tables AS
      SELECT c.oid::regclass::text AS identifier,
             c.oid,
             n.nspname AS schema,
             c.relname AS name,
             CASE p.partstrat
               WHEN 'l' THEN 'list'
               WHEN 'r' THEN 'range'
               WHEN 'h' THEN 'hash'
             END AS strategy,
             pg_get_partkeydef(c.oid) AS partition_key
      FROM pg_partitioned_table p
      JOIN pg_class c ON c.oid = p.partrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = current_schema();
    SQL

    execute <<~SQL.squish
      CREATE OR REPLACE VIEW postgres_partitions AS
      SELECT c.oid::regclass::text AS identifier,
             c.oid,
             n.nspname AS schema,
             c.relname AS name,
             i.inhparent::regclass::text AS parent_identifier,
             pg_get_expr(c.relpartbound, c.oid) AS condition,
             obj_description(c.oid) AS comment,
             i.inhrelid IS NOT NULL AS attached
      FROM pg_class c
      LEFT JOIN pg_inherits i ON c.oid = i.inhrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE c.relispartition
        AND c.relkind = 'r'
        AND n.nspname IN (current_schema(), #{quote(dynamic_schema)});
    SQL

    execute <<~SQL.squish
      CREATE OR REPLACE VIEW postgres_detached_partitions AS
      SELECT c.oid::regclass::text AS identifier,
             c.oid,
             n.nspname AS schema,
             c.relname AS name,
             obj_description(c.oid)::jsonb ->> 'table' AS parent_identifier,
             (obj_description(c.oid)::jsonb ->> 'detached_at')::timestamptz AS detached_at
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE c.relkind = 'r'
        AND n.nspname = #{quote(dynamic_schema)}
        AND NOT EXISTS (
          SELECT 1 FROM pg_inherits WHERE inhrelid = c.oid
        )
        AND obj_description(c.oid)::jsonb ? 'table'
        AND obj_description(c.oid)::jsonb ? 'detached_at';
    SQL
  end

  def down
    execute 'DROP VIEW IF EXISTS postgres_detached_partitions'
    execute 'DROP VIEW IF EXISTS postgres_partitions'
    execute 'DROP VIEW IF EXISTS postgres_partitioned_tables'
  end
end
