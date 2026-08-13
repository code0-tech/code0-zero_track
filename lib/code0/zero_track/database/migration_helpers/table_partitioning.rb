# frozen_string_literal: true

module Code0
  module ZeroTrack
    module Database
      module MigrationHelpers
        module TablePartitioning
          def create_partition_by_date_table(table_name, partition_column:, primary_key: nil, **options, &block)
            options[:options] = "PARTITION BY RANGE (#{quote_column_name(partition_column)})"
            options[:id] = false

            create_table(table_name, **options) do |t|
              t.bigserial :id, null: false unless primary_key

              block.call(t)
            end

            pk_columns = primary_key || [:id, partition_column]

            reversible do |dir|
              dir.up do
                execute <<~SQL.squish
                  ALTER TABLE #{quote_table_name(table_name)}
                  ADD PRIMARY KEY (#{pk_columns.map { |c| quote_column_name(c) }.join(', ')})
                SQL
              end
            end
          end

          def create_dynamic_partition_schema
            schema = quote_table_name(Rails.application.config.zero_track.db_partitioning.dynamic_partition_schema)
            execute "CREATE SCHEMA #{schema}"
          end

          def drop_dynamic_partition_schema
            schema = quote_table_name(Rails.application.config.zero_track.db_partitioning.dynamic_partition_schema)
            execute "DROP SCHEMA #{schema}"
          end

          def create_partitioning_views
            dynamic_schema = Rails.application.config.zero_track.db_partitioning.dynamic_partition_schema

            execute <<-SQL.squish
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

            execute <<-SQL.squish
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

            execute <<-SQL.squish
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

          def drop_partitioning_views
            execute 'DROP VIEW IF EXISTS postgres_detached_partitions'
            execute 'DROP VIEW IF EXISTS postgres_partitions'
            execute 'DROP VIEW IF EXISTS postgres_partitioned_tables'
          end
        end
      end
    end
  end
end
